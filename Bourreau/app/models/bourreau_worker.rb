
#
# CBRAIN Project
#
# This class implements a worker that manages the CBRAIN queue of tasks.
#
# Original authors: Pierre Rioux and Anton Zoubarev
#
# $Id$
#

#= Bourreau Worker Class
#
#This class implements a worker that manages the CBRAIN queue of tasks.
#This model is not an ActiveRecord class.
class BourreauWorker < Worker

  Revision_info="$Id$"

  def do_regular_work

    # Asks the DB for the list of tasks that need handling.
    worker_log.debug "Finding list of active tasks."
    tasks_todo = DrmaaTask.find(:all,
      :conditions => { :status      => [ 'New', 'Queued', 'On CPU', 'Data Ready' ],
                       :bourreau_id => CBRAIN::SelfRemoteResourceId } )
    worker_log.info "Found #{tasks_todo.size} tasks to handle."

    # Detects and turns on sleep mode.
    # This is the eternal SLEEP mode when there is nothing to do; it
    # lets our process be responsive to signals while not querying
    # the database all the time for nothing.
    # This mode is reset to normal 'scan' mode when receiving a USR1 signal
    # or at least once every hour (so that there is at least some
    # kind of DB activity; some DB servers close their socket otherwise)
    if tasks_todo.size == 0
      worker_log.info "No tasks need handling, going to eternal SLEEP state."
      request_sleep_mode(1.hour) # 'Eternal' is 1 hour !
      return
    end

    # Processes each task in the active list
    tasks_todo.each do |task|
      process_task(task) # this can take a long time...
      break if stop_signal_received?
    end

  end

  # This is the worker method that executes the necessary
  # code to make a task go from state *New* to *Setting* *Up*
  # and from state *Data* *Ready* to *Post* *Processing*.
  #
  # It also updates the statuses from *Queued* to
  # *On* *CPU* and *On* *CPU* to *Data* *Ready* based on
  # the activity on the cluster, but no code is run for
  # these transitions.
  def process_task(task)

    mypid = Process.pid

    task.reload
    worker_log.debug "--- Got #{task.bname_tid} in state #{task.status}"

    task.update_status
    worker_log.debug "Updated #{task.bname_tid} to state #{task.status}"

    case task.status
      when 'New'
        worker_log.debug "Start   #{task.bname_tid}"
        task.setup_and_submit_job do |thetask| # New -> Queued|Failed To Setup
          thetask.addlog_context(self,self.pretty_name)
        end
        worker_log.debug "     -> #{task.bname_tid} to state #{task.status}"
      when 'Data Ready'
        task.addlog_context(self,"Post Processing, PID=#{mypid}")
        worker_log.debug "PostPro #{task.bname_tid}"
        task.post_process do |thetask| # Data Ready -> Completed|Failed To PostProcess
          thetask.addlog_context(self,self.pretty_name)
        end
        worker_log.debug "     -> #{task.bname_tid} to state #{task.status}"
    end

    if task.status == 'Completed'
      Message.send_message(task.user,
                           :message_type  => :notice,
                           :header        => "Task #{task.name} Completed Successfully",
                           :description   => "Oh great!",
                           :variable_text => "[[#{task.bname_tid}][/tasks/show/#{task.id}]]"
                          )
    elsif task.status =~ /^Failed/
      Message.send_message(task.user,
                           :message_type  => :error,
                           :header        => "Task #{task.name} Failed",
                           :description   => "Sorry about that. Check the task's log.",
                           :variable_text => "[[#{task.bname_tid}][/tasks/show/#{task.id}]]"
                          )
    end

  # A CbrainTransitionException can occur at the very beginning of
  # setup_and_submit_job() or post_process(); it's allowed, it means
  # some other worker has beated us to the punch. So we just ignore it.
  rescue CbrainTransitionException => te
    worker_log.debug "Transition Exception: task '#{task.bname_tid}' FROM='#{te.from_state}' TO='#{te.to_state}"
    return

  # Any other error is critical and fatal; we're already
  # trapping all exceptions in setup_and_submit_job() and post_process(),
  # so if an exception went through anyway, it's a BUG.
  rescue => e
    worker_log.fatal "Exception processing task #{task.bname_tid}: #{e.class.to_s} #{e.message}\n" + e.backtrace[0..10].join("\n")
    raise e
  end

end
