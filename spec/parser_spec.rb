require 'spec_helper'

describe Orgmode::Parser do
  it "should open ORG files" do
    parser = Orgmode::Parser.load(RememberFile)
  end

  it "should fail on non-existant files" do
    lambda { parser = Orgmode::Parser.load("does-not-exist.org") }.should raise_error
  end

  it "should load all of the lines" do
    parser = Orgmode::Parser.load(RememberFile)
    parser.lines.length.should eql(53)
  end

  it "should find all headlines" do
    parser = Orgmode::Parser.load(RememberFile)
    parser.headlines.size.should eq(12)
  end

  it "can find a headline by index" do
    parser = Orgmode::Parser.load(RememberFile)
    line = parser.headlines[1].to_s
    line.should eql("** YAML header in Webby\n")
  end

  it "should determine headline levels" do
    parser = Orgmode::Parser.load(RememberFile)
    parser.headlines[0].level.should eql(1)
    parser.headlines[1].level.should eql(2)
  end

  it "should include the property drawer items from a headline" do
    parser = Orgmode::Parser.load(FreeformExampleFile)
    parser.headlines.first.property_drawer.count.should == 2
    parser.headlines.first.property_drawer['DATE'].should == '2009-11-26'
    parser.headlines.first.property_drawer['SLUG'].should == 'future-ideas'
  end

  it "should put body lines in headlines" do
    parser = Orgmode::Parser.load(RememberFile)
    parser.headlines[0].body_lines.size.should eq(1)
    parser.headlines[1].body_lines.size.should eq(7)
  end

  it "should understand lines before the first headline" do
    parser = Orgmode::Parser.load(FreeformFile)
    parser.header_lines.size.should eq(19)
  end

  it "should load in-buffer settings" do
    parser = Orgmode::Parser.load(FreeformFile)
    parser.in_buffer_settings.size.should eq(12)
    parser.in_buffer_settings["TITLE"].should eql("Freeform")
    parser.in_buffer_settings["EMAIL"].should eql("bdewey@gmail.com")
    parser.in_buffer_settings["LANGUAGE"].should eql("en")
  end

  it "should understand OPTIONS" do
    parser = Orgmode::Parser.load(FreeformFile)
    parser.options.size.should eq(19)
    parser.options["TeX"].should eql("t")
    parser.options["todo"].should eql("t")
    parser.options["\\n"].should eql("nil")
    parser.export_todo?.should be_truthy
    parser.options.delete("todo")
    parser.export_todo?.should be false
  end

  it "should skip in-buffer settings inside EXAMPLE blocks" do
    parser = Orgmode::Parser.load(FreeformExampleFile)
    parser.in_buffer_settings.size.should eq(0)
  end

  it "should return a textile string" do
    parser = Orgmode::Parser.load(FreeformFile)
    parser.to_textile.should be_kind_of(String)
  end

  it "should understand export table option" do
    fname = File.join(File.dirname(__FILE__), %w[html_examples skip-table.org])
    data = IO.read(fname)
    p = Orgmode::Parser.new(data)
    p.export_tables?.should be false
  end

  context "with a table that begins with a separator line" do
    let(:parser) { Orgmode::Parser.new(data) }
    let(:data) { Pathname.new(File.dirname(__FILE__)).join('data', 'tables.org').read }

    it "should parse without errors" do
      parser.headlines.size.should == 2
    end
  end

  describe "Custom keyword parser" do
    fname = File.join(File.dirname(__FILE__), %w[html_examples custom-todo.org])
    p = Orgmode::Parser.load(fname)
    valid_keywords = %w[TODO INPROGRESS WAITING DONE CANCELED]
    invalid_keywords = %w[TODOX todo inprogress Waiting done cANCELED NEXT |]
    valid_keywords.each do |kw|
      it "should match custom keyword #{kw}" do
        (kw =~ p.custom_keyword_regexp).should be_truthy
      end
    end
    invalid_keywords.each do |kw|
      it "should not match custom keyword #{kw}" do
        (kw =~ p.custom_keyword_regexp).should be_nil
      end
    end
    it "should not match blank as a custom keyword" do
      ("" =~ p.custom_keyword_regexp).should be_nil
    end
  end

  describe "Custom include/exclude parser" do
    fname = File.join(File.dirname(__FILE__), %w[html_examples export-tags.org])
    p = Orgmode::Parser.load(fname)
    it "should load tags" do
      p.export_exclude_tags.size.should eq(2)
      p.export_select_tags.size.should eq(1)
    end
  end

  describe "Export to Textile test cases" do
    data_directory = File.join(File.dirname(__FILE__), "textile_examples")
    org_files = File.expand_path(File.join(data_directory, "*.org" ))
    files = Dir.glob(org_files)
    files.each do |file|
      basename = File.basename(file, ".org")
      textile_name = File.join(data_directory, basename + ".textile")
      textile_name = File.expand_path(textile_name)

      it "should convert #{basename}.org to Textile" do
        expected = IO.read(textile_name)
        expected.should be_kind_of(String)
        parser = Orgmode::Parser.new(IO.read(file))
        actual = parser.to_textile
        actual.should be_kind_of(String)
        actual.should == expected
      end
    end
  end

  describe "Export to HTML test cases" do
    # Dynamic generation of examples from each *.org file in html_examples.
    # Each of these files is convertable to HTML.
    data_directory = File.join(File.dirname(__FILE__), "html_examples")
    org_files = File.expand_path(File.join(data_directory, "*.org" ))
    files = Dir.glob(org_files)
    files.each do |file|
      basename = File.basename(file, ".org")
      textile_name = File.join(data_directory, basename + ".html")
      textile_name = File.expand_path(textile_name)

      it "should convert #{basename}.org to HTML" do
        expected = IO.read(textile_name)
        expected.should be_kind_of(String)
        parser = Orgmode::Parser.new(IO.read(file), { :allow_include_files => true })
        actual = parser.to_html
        actual.should be_kind_of(String)
        actual.should == expected
      end

      it "should render #{basename}.org to HTML using Tilt templates" do
        ENV['ORG_RUBY_ENABLE_INCLUDE_FILES'] = 'true'
        expected = IO.read(textile_name)
        template = Tilt.new(file).render
        template.should == expected
        ENV['ORG_RUBY_ENABLE_INCLUDE_FILES'] = ''
      end
    end

    it "should not render #+INCLUDE directive when explicitly indicated" do
      data_directory = File.join(File.dirname(__FILE__), "html_examples")
      expected = File.read(File.join(data_directory, "include-file-disabled.html"))
      org_file = File.join(data_directory, "include-file.org")
      parser = Orgmode::Parser.new(IO.read(org_file), :allow_include_files => false)
      actual = parser.to_html
      actual.should == expected
    end

    it "should render #+INCLUDE when ORG_RUBY_INCLUDE_ROOT is set" do
      data_directory = File.expand_path(File.join(File.dirname(__FILE__), "html_examples"))
      ENV['ORG_RUBY_INCLUDE_ROOT'] = data_directory
      expected = File.read(File.join(data_directory, "include-file.html"))
      org_file = File.join(data_directory, "include-file.org")
      parser = Orgmode::Parser.new(IO.read(org_file))
      actual = parser.to_html
      actual.should == expected
      ENV['ORG_RUBY_INCLUDE_ROOT'] = nil
    end
  end

  describe "Export to HTML test cases with code syntax highlight" do
    code_syntax_examples_directory = File.join(File.dirname(__FILE__), "html_code_syntax_highlight_examples")

    # Include the code syntax highlight support tests
    if defined? CodeRay
      # Use CodeRay for syntax highlight (pure Ruby solution)
      org_files = File.expand_path(File.join(code_syntax_examples_directory, "*-coderay.org"))
    elsif defined? Pygments
      # Use pygments (so that it works with Jekyll, Gollum and possibly Github)
      org_files = File.expand_path(File.join(code_syntax_examples_directory, "*-pygments.org"))
    else
      # Do not use syntax coloring for source code blocks
      org_files = File.expand_path(File.join(code_syntax_examples_directory, "*-no-color.org"))
    end
    files = Dir.glob(org_files)

    files.each do |file|
      basename = File.basename(file, ".org")
      org_filename = File.join(code_syntax_examples_directory, basename + ".html")
      org_filename = File.expand_path(org_filename)

      it "should convert #{basename}.org to HTML" do
        expected = IO.read(org_filename)
        expected.should be_kind_of(String)
        parser = Orgmode::Parser.new(IO.read(file), :allow_include_files => true)
        actual = parser.to_html
        actual.should be_kind_of(String)
        actual.should == expected
      end

      it "should render #{basename}.org to HTML using Tilt templates" do
        ENV['ORG_RUBY_ENABLE_INCLUDE_FILES'] = 'true'
        expected = IO.read(org_filename)
        template = Tilt.new(file).render
        template.should == expected
        ENV['ORG_RUBY_ENABLE_INCLUDE_FILES'] = ''
      end
    end
  end

  describe "Export to Markdown test cases" do
    data_directory = File.join(File.dirname(__FILE__), "markdown_examples")
    org_files = File.expand_path(File.join(data_directory, "*.org" ))
    files = Dir.glob(org_files)
    files.each do |file|
      basename = File.basename(file, ".org")
      markdown_name = File.join(data_directory, basename + ".md")
      markdown_name = File.expand_path(markdown_name)

      it "should convert #{basename}.org to Markdown" do
        expected = IO.read(markdown_name)
        expected.should be_kind_of(String)
        parser = Orgmode::Parser.new(IO.read(file), :allow_include_files => false)
        actual = parser.to_markdown
        actual.should be_kind_of(String)
        actual.should == expected
      end
    end
  end
end

