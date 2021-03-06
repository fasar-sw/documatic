# encoding: utf-8

require 'rexml/document'
require 'rexml/attribute'
require 'zip/zip'
require 'erb'
require 'fileutils'

module Documatic::OpenDocumentText
  class Template
    include ERB::Util

    # The template's content component.  This is an instance of
    # Documatic::Component, instantiated from the compiled (embedded
    # Ruby) version of 'content.xml'.
    attr_accessor :content
    # The template's styles component.  This is an instance of
    # Documatic::Component, instantiated from the compiled (embedded
    # Ruby) version of 'styles.xml'.
    attr_accessor :styles
    # The template's JAR file (i.e. an instance of Zip::ZipFile)
    attr_accessor :jar
    # The raw contents of 'content.xml'.
    attr_accessor :content_raw
    # Compiled text, to be written to 'content.erb'
    attr_accessor :content_erb
    # The raw contents of 'styles.xml'
    attr_accessor :styles_raw
    # Compiled text, to be written to 'styles.erb'
    attr_accessor :styles_erb

    # RE_STYLES match positions
    STYLE_NAME = 1
    STYLE_TYPE = 2
    
    # RE_ERB match positions
    TYPE       =  5
    ERB_CODE   =  6
    
    ROW_START  =  1
    ROW_END    = 11

    ITEM_START =  2
    ITEM_END   = 10
    
    PARA_START =  3
    PARA_END   =  9
    
    SPAN_END   =  4
    SPAN_START =  8
    
    # Match types:
    TABLE_ROW = 1
    PARAGRAPH = 2
    INLINE_CODE = 3
    VALUE = 4

    # Abbrevs
    DTC = Documatic::OpenDocumentText::Component
    
    class << self
      # Process a template and save it to an output file.
      #
      # The argument is a hash with the keys :options and :data.
      # :options should contain an object that responds to
      # #template_file and #output_file.  #template_file is the path
      # and filename to the OpenDocument template to be used;
      # #output_file is where the processed results will be stored.
      # The #template_file must exist, and the #output_file path must
      # either exist or the current process must be able to create it.
      #
      # An optional block can be provided to this method.  The block
      # will be passed the template currently being processed (i.e. an
      # instance of Documatic::OpenDocumentText::Template).  The block
      # can peform manipulation of the template directly by
      # e.g. accessing the template's JAR or the content or styles
      # components.  The template will be saved after the block exits.
      def process_template(args, &block)
        raise(
          ArgumentError,
          'Need to specify both :template_file and :output_file in options'
        ) unless( args[:options] && args[:options].template_file &&
                  args[:options].output_file )

        output_dir = File.dirname(args[:options].output_file)
        File.directory?(output_dir) || FileUtils.mkdir_p(output_dir)
        FileUtils.cp(args[:options].template_file, args[:options].output_file)

        template = self.new( args[:options].output_file )
        template.process( :data => args[:data], :options => args[:options],
                          :template => template, :master => template )
        template.save()
        if block
          block.call(template)
          template.save()
        end
        template.close
      end

    end  # class << self
    # -------------------------------------------------------------------------


    def initialize(filename)
      @filename = filename
      @jar = Zip::ZipFile.open(@filename)
      return true
    end
    # -------------------------------------------------------------------------


    # Compile and process a template at the same time.
    #
    # This method invokes <tt>DTC#process()</tt> passing all the specified options
    # in Hash form. Basic supported keys are:
    #
    # :data     => data to be processed
    # :options  => processing options
    # :template => Template instance to be processed
    # :master   => Master Template instance
    #
    def process( local_assigns = {} )
      # Compile this template, if not compiled already.
      self.jar.find_entry('documatic/master') || self.compile
      # Process the styles (incl. headers and footers).
      # This is conditional because partials don't need styles.erb.
      @styles = DTC.new(self.jar.read('documatic/master/styles.erb') )
      @styles.process(local_assigns)
      # Process the main (body) content.
      @content = DTC.new( self.jar.read('documatic/master/content.erb') )
      @content.process( local_assigns )
      # Merge styles from any partials into the main template
      if self.partials.keys.length > 0
        @content.merge_partial_styles(self.partials.values)
      end
      # Copy any images into this jar
      if images.length > 0
        self.jar.find_entry('Pictures') || self.jar.mkdir('Pictures')
        images.keys.each do |filename|
          path = images.delete(filename)
          self.jar.add("Pictures/#{filename}", path)
        end
      end
    end
    # -------------------------------------------------------------------------


    def save
      # Gather all the styles from the partials, add them to the master's styles.
      # Put the body into the document.
      self.jar.get_output_stream('content.xml') do |f|
        f.write self.content.to_s
      end

      if self.styles
        self.jar.get_output_stream('styles.xml') do |f|
          f.write self.styles.to_s
        end
      end
    end
    # -------------------------------------------------------------------------


    def close                                       # Remove compiled content before closing to avoid corruption of files:
      self.jar.remove('documatic/master/styles.erb')
      self.jar.remove('documatic/master/content.erb')
      self.jar.close
    end
    # -------------------------------------------------------------------------


    # Simply compiles the Template
    #
    def compile
      # Read the raw files
      @content_raw = pretty_xml('content.xml')
      @styles_raw = pretty_xml('styles.xml')
      
      @content_erb = self.erbify(@content_raw)
      @styles_erb = self.erbify(@styles_raw)

      # Create 'documatic/master/' in zip file
      self.jar.find_entry('documatic/master') || self.jar.mkdir('documatic/master')
      
      self.jar.get_output_stream('documatic/master/content.erb') do |f|
        f.write @content_erb
      end
      self.jar.get_output_stream('documatic/master/styles.erb') do |f|
        f.write @styles_erb
      end
    end
    # -------------------------------------------------------------------------


    # Returns a hash of images added during the processing of the
    # current template.  (This method is not intended to be called
    # directly by application developers: it is used indirectly by
    # the #image helper to add images from within an OpenDocument
    # template.)
    def images
      @images ||= Hash.new
    end        

    
    # Add an image to the current template.  The argument is the
    # path and filename of the image to be added to the template.
    # This can be an absolute path or a relative path to the current
    # directory.  Returns the basename of file if it exists;
    # otherwise an ArgumentError exception is raised.
    def add_image(full_path)
      if File.exists?(full_path)
        image = File.basename(full_path)
        self.images[image] = full_path
        return image
      else
        raise ArgumentError, 'Attempted to add non-existent image to template'
      end
    end


    def partials
      @partials ||= Hash.new
    end


    def add_partial(full_path, partial)
      self.partials[full_path] = partial
    end
    # -------------------------------------------------------------------------

    
    protected


    def pretty_xml(filename)
      # Pretty print the XML source
      xml_doc = REXML::Document.new(self.jar.read(filename))
      xml_text = String.new
#      xml_doc.write(xml_text, Documatic.debug ? 0 : -1)
      xml_doc.write(xml_text, 0)
      return xml_text
    end
    # -------------------------------------------------------------------------


    # Change OpenDocument line breaks and tabs in the ERb code to regular characters.
    def unnormalize(code)
      code = code.gsub(/<text:line-break\/>/, "\n")
      code = code.gsub(/<text:tab\/>/, "\t")
      code = code.gsub(/<text:s(\/|(\s[^>]*))>/, " ")
      return REXML::Text.unnormalize(code)
    end
    # -------------------------------------------------------------------------


    # Massage OpenDocument XML into ERb.  (This is the heart of the compiler.)
    def erbify(code)
      # First gather all the ERb-related derived styles
      remaining = code
      styles = {'Ruby_20_Code' => 'Code', 'Ruby_20_Value' => 'Value',
        'Ruby_20_Block' => 'Block', 'Ruby_20_Literal' => 'Literal'}
      re_styles = /<style:style style:name="([^"]+)"[^>]* style:parent-style-name="Ruby_20_(Code|Value|Block|Literal)"[^>]*>/

      while remaining.length > 0
        md = re_styles.match remaining
        if md
          styles[md[STYLE_NAME]] = md[STYLE_TYPE]
          remaining = md.post_match
        else
          remaining = ""
        end
      end
      
      remaining = code
      result = String.new
      
      # Then make a RE that includes the ERb-related styles.
      # Match positions:
      # 
      #  1. ROW_START   Begin table row ?
      #  2. ITEM_START  Begin list item ?
      #  3. PARA_START  Begin paragraph ?
      #  4. SPAN_END    Another text span ends immediately before ERb ?
      #  --5. SPACE       (possible leading space)
      #  5. TYPE        ERb text style type
      #  6. ERB_CODE    ERb code
      #  7.             (ERb inner brackets)
      #  8. SPAN_START  Another text span begins immediately after ERb ?
      #  9. PARA_END    End paragraph ?
      # 10. ITEM_END    End list item ?
      # 11. ROW_END     End table row (incl. covered rows) ?
      #
      # "?": optional, might not occur every time
#      re_erb = /(<table:table-row[^>]*>\s*<table:table-cell [^>]+>\s*)?(\s*<text:list-item>\s*)?\s*(<text:p [^>]+>\s*)?(<\/text:span>)?<text:span text:style-name="(#{styles.keys.join '|'})">(([^<]*|<text:line-break\/>|<text:tab\/>)+)<\/text:span>(<text:span [^>]+>)?(\s*<\/text:p>\s*)?(<\/text:list-item>\s*)?(<\/table:table-cell>\s*(<table:covered-table-cell\/>\s*)*<\/table:table-row>)?/
      re_erb = /(<table:table-row[^>]*>\s*<table:table-cell [^>]+>\s*)?(<text:list-item>\s*)?(<text:p [^>]+>\s*)?(<\/text:span>\s*)?<text:span text:style-name="(#{styles.keys.join '|'})">(([^<]*|<text:line-break\/>|<text:tab\/>)+)<\/text:span>(<text:span [^>]+>)?(\s*<\/text:p>)?(\s*<\/text:list-item>)?(\s*<\/table:table-cell>(\s*<table:covered-table-cell\/>)*\s*<\/table:table-row>)?/

      # Then search for all text using those styles
      while remaining.length > 0

        md = re_erb.match remaining
        
        if md
          result += md.pre_match
          
          match_code = false
          match_row  = false
          match_item = false
          match_para = false
          match_span = false

          if styles[md[TYPE]] == 'Code'
            match_code = true
            delim_start = '<% ' ; delim_end = ' %>'
            if md[PARA_START] and md[PARA_END]
              match_para = true
              if md[ITEM_START] and md[ITEM_END]
                match_item = true
              end
              if md[ROW_START] and md[ROW_END]
                match_row = true
              end
            end
          elsif styles[md[TYPE]] == 'Block'
            delim_start = '<%= ' ; delim_end = ' %>'
            if md[PARA_START] and md[PARA_END]
              match_para = true
            end
          else  # style is Value or Literal
            if styles[md[TYPE]] == 'Literal'
              delim_start = '<%= ' ; delim_end = ' %>'
            else
              delim_start = '<%= ERB::Util.h(' ; delim_end = ') %>'
            end
            
            if md[SPAN_END] and md[SPAN_START]
              match_span = true
            end
          end
          
          if md[ROW_START] and not match_row
            result += md[ROW_START]
          end

          if md[ITEM_START] and not match_item
            result += md[ITEM_START]
          end
          
          if md[PARA_START] and not match_para
            result += md[PARA_START]
          end
          
          # Text formatting before ERb
          if match_code
            if md[SPAN_END]
              result += md[SPAN_END]
            end
          else
            #if md[SPACE]
            #  result += md[SPACE]
            #end
            if md[SPAN_START] and not md[SPAN_END]
              result += md[SPAN_START]
            end
          end
          
          result += "#{delim_start}#{self.unnormalize md[ERB_CODE]}#{delim_end}"
          
          # Text formatting after ERb
          if match_code
            if md[SPAN_START]
              result += md[SPAN_START]
            end
          else
            if md[SPAN_END]
              result += md[SPAN_END]
              if md[SPAN_START]
                result += md[SPAN_START]
              end
            end
          end

          if md[PARA_END] and not match_para
            result += md[PARA_END]
          end

          if md[ITEM_END] and not match_item
            result += md[ITEM_END]
          end
          
          if md[ROW_END] and not match_row
          result += md[ROW_END]
          end
          
          remaining = md.post_match
          
        else  # no further matches
          result += remaining
          remaining = ""
        end
      end
      
      return result
    end
    # -------------------------------------------------------------------------

  end
  # ---------------------------------------------------------------------------
end
