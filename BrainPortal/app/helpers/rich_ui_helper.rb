#Helper for dynamic, non-ajax interface elements.
module RichUiHelper
  
  Revision_info=CbrainFileRevision[__FILE__] 
  
  include JavascriptOptionSetup

  # Takes a +description+ (a string with possibly multiple lines) and shows
  # the first line only; other lines if present will be made accessible
  # through a link called '(more)' which launches an overlay.
  def overlay_description(description="", options={})
    return "" if description.blank?
    header = description.lines.first.strip
    body   = (description[header.size,999] || "").strip
    cropped_header = crop_text_to(options[:header_width] || 50,header)
    return h(cropped_header) if body.blank? && cropped_header !~ /\.\.\.$/

    link = h(cropped_header) + " " + 
      html_tool_tip(link_to("(more)", "#")) do
        ("<h4>#{h(header)}</h4>\n<pre>" + h(body) + "</pre>").html_safe
      end
    link.html_safe
  end
  
  #Create tab bars in the interface.
   #Content is provided with a block.
   #[options] A hash of html options for the tab bar structure.
   #Usage:
   # <% build_tabs do |tb| %>
   #   <% tb.tab "First Tab" do %>
   #      <h1>First tab contents</h1>
   #      More contents.
   #   <% end %>
   #   <% tb.tab "Second Tab" do %>
   #      Wow! Even more contents!
   #   <% end %>
   # <% end %>
   #
   #
   def build_tabs(options = {}, &block)
      bar = TabBuilder.new

      options[:class] ||= ""
      options[:class] +=  " tabs"

      atts = options.to_html_attributes

      capture(bar,&block)  #Load content into bar object

      safe_concat("<div #{atts}>")
      safe_concat(bar.tab_titles)
      safe_concat(bar.tab_divs)
      safe_concat("</div>")
      ""
    end

   ############################################################
   #                                              
   # Utility class for the build_tabs method (see above).      
   #                                                                          
   #############################################################
   class TabBuilder

     def initialize
       @tab_titles = ""
       @tab_divs   = ""
     end

     def tab_titles
       ("<ul>\n" + @tab_titles + "\n</ul>\n").html_safe
     end



     attr_reader :tab_divs

     #This creates an individual tab, it either takes a block and/or a partial as an option (:partial => "partial")
     def tab(name, &block)
       capture = eval("method(:capture)", block.binding)
       @tab_titles += "<li><a href='##{name.gsub(/\s+/,'_')}'>#{name}</a></li>"


       #########################################
       #tab content div.                       #
       #                                       #
       #This can be either a partial or a block#
       #########################################
       @tab_divs += "<div id=#{name.gsub(/\s+/,'_')}>\n"
       @tab_divs += capture.call(&block)
       @tab_divs += "</div>\n"
       ""
     end
   end


   #Create accordion menus in the interface.
   #Content is provided with a block.
   #[options] A hash of html options for the accordion structure.
   #Usage:
   # <% build_accordion do |acc| %>
   #   <% acc.section "Section Header" do %>
   #      <h1>First section contents</h1>
   #      More contents.
   #   <% end %>
   #   <% acc.section "Section Two" do %>
   #      Wow! Even more contents!
   #   <% end %>
   # <% end %>
   #
   #
   def build_accordion(options = {}, &block)
     options[:class] ||= ""
     options[:class] +=  " accordion"

     atts = options.to_html_attributes

     content = capture(AccordionBuilder.new, &block)

     safe_concat("<div #{atts}>")
     safe_concat(content)
     safe_concat("</div>")
     ""
   end

   ############################################################
   #                                              
   # Utility class for the build_accordion method (see above).      
   #                                                                          
   #############################################################
   class AccordionBuilder
     def section(header, &block)
       capture     = eval("method(:capture)",     block.binding)
       safe_concat = eval("method(:safe_concat)", block.binding)
       head = "<h3><a href=\"#\">#{header}</a></h3>"
       body = "<div style=\"display: none\">#{capture.call(&block)}</div>"
       safe_concat.call(head)
       safe_concat.call(body)
       ""
     end
   end
   
   #Create a tooltip that displays html when mouseovered.
   #Text of the icon is provided as an argument.
   #Html to be displayed on mouseover is given as a block.
   def html_tool_tip(text = "<span class=\"action_link\">?</span>".html_safe, options = {}, &block)
     @@html_tool_tip_id ||= 0
     @@html_tool_tip_id += 1

     html_tool_tip_id = @@html_tool_tip_id.to_s # we need a local var in case the block rendered ALSO calls html_tool_tip inside !
     html_tool_tip_id += "_#{Process.pid}_#{rand(1000000)}" # because of async ajax requests

     offset_x = options[:offset_x] || 30
     offset_y = options[:offset_y] || 0

     content = capture(&block) # here, new calls to html_tool_tip can be made.

     result = "<span class=\"html_tool_tip_trigger\" id=\"xsp_#{html_tool_tip_id}\" data-tool-tip-id=\"html_tool_tip_#{html_tool_tip_id}\" data-offset-x=\"#{offset_x}\" data-offset-y=\"#{offset_y}\">"
     result += h(text)
     result += "</span>"

     content_class = options.delete(:tooltip_div_class) || "html_tool_tip"
     result += "<div id=\"html_tool_tip_#{html_tool_tip_id}\" class=\"#{content_class}\">"
     result += h(content)
     result += "</div>"

     result.html_safe
   end
   
   #Create an overlay dialog box with a link as the button.
   #Content is provided through a block.
   #Options: 
   # [width] width in pixels of the overlay.
   #
   #All other options will be treated at HTML attributes.
   #
   #Usage:
   # <% overlay_content "Click me" do %>
   #   This content will be in the overlay
   # <% end %>
   #
   def overlay_content_link(name, options = {}, &block)
     options_setup("overlay_content_link", options)
     options[:href] ||= "#"

     element = options.delete(:enclosing_element) || "div"

     atts = options.to_html_attributes

     content = capture(&block)
     return "" if content.blank?

     html = <<-"HTML"
     <#{element} class="overlay_dialog">
       <a #{atts}>#{h(name)}</a>
       <div class="overlay_content" style="display: none;">#{h(content)}</div>
     </#{element}>
     HTML
     html.html_safe
   end

   #Create a button with a drop down menu
   #
   #Options:
   #[:partial] a partial to render as the content of the menu.
   #[:content_id] id of the menu section of the structure.
   #[:button_id] id of the button itself.
   #All other options are treated as HTML attributes on the
   #enclosing span.
   def button_with_dropdown_menu(title, options={}, &block)
     partial    = options.delete :partial
     content_id = options.delete :content_id
     content_id = "id=\"#{content_id}\"" if content_id
     button_id = options.delete :button_id
     button_id = "id=\"#{button_id}\"" if button_id
     options[:class] ||= ""
     options[:class] +=  " button_with_drop_down"
     if options.delete :open
       options["data-open"] = true
       display_style = "style=\"display: block\" "
     else
       display_style = "style=\"display: none\" "
     end

     content=""
     if block_given?
       content += capture(&block)
     end
     if partial
       content += render :partial => partial
     end

     atts = options.to_html_attributes
     safe_concat("<span #{atts}>")
     safe_concat("<a #{button_id} class=\"button_menu\">#{title}</a>")
     safe_concat("<div #{content_id} ABCD=1 #{display_style}class=\"drop_down_menu\">")
     safe_concat(content)
     safe_concat("</div>")
     safe_concat("</span>")
     ""
   end
   
   #Create an element that will toggle between hiding and showing another element.
   #The appearance/disappearance can also be animated.
   def show_hide_toggle(text, target, options = {})
     element_type = options.delete(:element_type) || "a"
     if element_type.downcase == "a"
       options["href"] ||= "#"
     end
     options["data-target"] = target
     alternate_text = options.delete(:alternate_text)
     if alternate_text
       options["data-alternate-text"] = alternate_text
     end
     slide_effect = options.delete(:slide_effect)
     if slide_effect
       options["data-slide-effect"] = true
     end
     slide_duration = options.delete(:slide_duration)
     if slide_duration
       options["data-slide-duration"] = slide_duration
     end

     options[:class] ||= ""
     options[:class] +=  " show_toggle"

     atts = options.to_html_attributes
     return " <#{element_type} #{atts}>#{h(text)}</#{element_type}>".html_safe
   end
   
end