require 'nokogiri'

require 'xml_support'
require 'support_files'

module AkomaNtoso
  NS = "http://www.akomantoso.org/2.0"

  # Wraps an AkomaNtoso XML document describing an Act.
  class Act

    # Allow us to jump from the XML document for an act to the
    # Act instance itself
    @@acts = {}

    attr_accessor :doc, :meta, :body, :num, :year, :id_uri
    attr_accessor :filename

    # Find all XML files in +path+ and return
    # a list of instances.
    def self.discover(path)
      acts = []

      for fname in Dir.glob("#{path}/**/*.xml")
        acts << self.from_file(fname)
      end

      acts
    end

    # Create an instance by reading in the act from a file.
    def self.from_file(filename)
      act = self.new
      act.file(filename)
      act
    end

    def self.from_node(node)
      @@acts[node.document]
    end

    # Create a new instance
    def initialize
    end

    # Load the XML from +filename+
    def file(filename)
      @filename = filename

      File.open(filename) { |f| parse(f) }
    end
    
    # Parse the XML contained in the file-like object +io+
    def parse(io)
      @doc = Nokogiri::XML(io)
      @meta = @doc.at_xpath('/a:akomaNtoso/a:act/a:meta', a: NS)
      @body = @doc.at_xpath('/a:akomaNtoso/a:act/a:body', a: NS)

      @@acts[@doc] = self

      extract_id
    end

    def extract_id
      @id_uri = @meta.at_xpath('./a:identification/a:FRBRWork/a:FRBRuri', a: NS)['value']
      empty, @country, type, date, @num = @id_uri.split('/')

      # yyyy-mm-dd
      @year = date.split('-', 2)[0]
    end

    def short_title
      unless @short_title
        node = @meta.at_xpath('./a:identification/a:FRBRWork/a:FRBRalias', a: NS)
        if node
          @short_title = node['value']
        else
          @short_title = "Act #{num} of #{year}"
        end
      end

      @short_title
    end

    def url_path
      "/#{@country}/acts/#{@year}/#{@num}/"
    end

    def url_file
      "act-#{@year}-#{@num}"
    end

    # Has this act been amended?
    def amended?
      @doc.at_xpath('/a:akomaNtoso/a:act', a: NS)['contains'] != 'originalVersion'
    end

    # Does this Act have parts?
    def parts?
      !parts.empty?
    end

    def parts
      @body.xpath('./a:part', a: NS)
    end

    def chapters?
      !chapters.empty?
    end

    def chapters
      @body.xpath('./a:chapter', a: NS)
    end
    
    def sections
      @body.xpath('.//a:section', a: NS)
    end

    # The XML node representing the definitions section
    def definitions
      # try looking for the definition list
      defn = @body.at_css('list#definitions')
      return defn.parent if defn

      # try looking for the heading
      defn = @body.at_xpath('.//a:section/a:heading[text() = "Definitions"]', a: NS)
      return defn.parent if defn

      nil
    end

    # The XML node representing the schedules document
    def schedules
      @doc.at_xpath('/a:akomaNtoso/a:components/a:component/a:doc[@name="schedules"]/a:mainBody', a: NS)
    end

    # Get a map from term ids to +[term, defn]+ pairs,
    # where +term+ is the text term NS+defn+ is
    # the XML node with the definition in it.
    def term_definitions
      terms = {}

      @meta.xpath('a:references/a:TLCTerm', a: NS).each do |node|
        # <TLCTerm id="term-affected_land" href="/ontology/term/this.eng.affected_land" showAs="affected land"/>

        # find the point with id 'def-term-foo'
        defn = @body.at_xpath(".//a:point[@id='def-#{node['id']}']", a: NS)

        # try find the def itself, then find the wrapping list > point node
        unless defn
          defn = @body.at_xpath(".//a:def[@refersTo='##{node['id']}']", a: NS)
          while defn NSdefn.parent.name != 'list'
            defn = defn.parent
          end
        end

        next unless defn

        terms[node['id']] = [node['showAs'], defn]
      end

      terms
    end

    # Returns the publication element, if any.
    def publication
      @meta.at_xpath('./a:publication', a: AkomaNtoso::NS)
    end

    # A SupportFilesCollection instance for this act.
    def support_files
      @support_files ||= SupportFileCollection.for_act(self)
    end

    def nature
      "act"
    end

    def inspect
      "<#{self.class.name} @id_uri=\"#{@id_uri}\">"
    end
  end

end