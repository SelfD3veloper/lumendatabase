require 'rails_helper'
require 'ingestor'

describe Ingestor::Legacy do

  describe 'by hand' do
    before do
      @error_handler = double.as_null_object
      allow(described_class::ErrorHandler).to receive(:new).and_return(@error_handler)

      @attribute_mapper = double("AttributeMapper")
      allow(@attribute_mapper).to receive(:exclude?).and_return(false)
      allow(@attribute_mapper).to receive(:notice_type).and_return(DMCA)
      allow(@attribute_mapper).to receive(:mapped).and_return({})
      allow(described_class::AttributeMapper).to receive(:new).and_return(@attribute_mapper)
    end

    it "instantiates the correct notice type based on AttributeMapper" do
      allow(@attribute_mapper).to receive(:notice_type).and_return(Trademark)
      expect(Trademark).to receive(:new).at_least(:once).and_return(Trademark.new)

      importer.import
    end

    it "attempts to find a notice by original_notice_id before importing" do
      dmca = DMCA.new

      existing_notice_ids.each do |original_notice_id|
        expect(Notice).to receive(:where).with(original_notice_id: original_notice_id).once.and_return(dmca)
      end

      expect(DMCA).not_to receive(:create!)

      importer.import
    end

    def importer
      sample_file = "spec/support/example_files/example_notice_export.csv"
      record_source = Ingestor::Legacy::RecordSource::CSV.new(sample_file)

      described_class.new(record_source).tap do |importer|
        importer.logger.level = ::Logger::FATAL
      end
    end

    def existing_notice_ids
      File.open("spec/support/example_files/example_notice_export.csv").map do |line|
        line.split(',').first
      end[1,20]
    end
  end

  describe 'by csv' do
    before do
      create(:topic, name: 'Foobar')
      ingestor = Ingestor::Legacy.open_csv(
        'spec/support/example_files/example_notice_export.csv'
      )
      ingestor.logger.level = Logger::ERROR
      ingestor.import
      (
        @primary_format_notice,
        @secondary_dmca_notice,
        @twitter_notice,
        @primary_notice_without_data
      ) = DMCA.order(:id)

      (
        @secondary_other_notice,
        @youtube_defamation_notice,
      ) = Defamation.order(:id)

      @youtube_otherlegal_notice = Other.last

      (
       @youtube_trademark_d_notice,
       @youtube_trademark_b_notice,
       @youtube_counterfeit_notice,
      ) = Trademark.order(:id)
    end

    after do
      FileUtils.rm_rf 'spec/support/example_files-failures/'
    end

    context "from the Youtube otherlegal format" do
      subject(:notice) { @youtube_otherlegal_notice }

      it "notices are created" do
        expect(notice.title).to eq 'Takedown Request regarding Other Legal Complaint to YouTube'
        expect(notice.works.length).to eq 1
        expect(notice.infringing_urls.map(&:url)).to match_array(
          %w|https://www.youtube.com/watch?v=xszr9lUlPE8
  https://www.youtube.com/watch?v=w2-DjJ
  https://www.youtube.com/watch?v=PlsCEe|
        )
        expect(notice.size).to eq(1)
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 10078
      end

      it "the correct entities are created" do
        expect(notice).to have(3).entity_notice_roles
        expect(notice.sender.name).to eq "PeterDancer"
        expect(notice.principal.name).to eq "Peter Dancer"
        expect(notice.recipient_name).to eq "Google, Inc."
        expect(notice.tag_list).to include( 'youtube' )
      end
    end

    context "from the Youtube counterfeit format" do
      subject(:notice) { @youtube_counterfeit_notice }

      it "notices are created" do
        expect(notice.title).to eq 'Takedown Request regarding Counterfeit Complaint to YouTube'
        expect(notice.works.length).to eq 1
        expect(notice.infringing_urls.map(&:url)).to match_array(
          %w|http://www.youtube.com/watch?v=H0r8U-|
        )
        expect(notice.size).to eq(1)
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 1007
        expect(notice.mark_registration_number).to eq '12200000'
      end

      it "the correct entities are created" do
        expect(notice).to have(3).entity_notice_roles
        expect(notice.sender_name).to eq "Adelaid Bourbou, Internet Unit, The Federation"
        expect(notice.principal_name).to eq "Humboldt SA, Genève"
        expect(notice.recipient_name).to eq "Google, Inc."
        expect(notice.tag_list).to include( 'youtube' )
      end
    end

    context "from the Youtube Trademark-b format" do
      subject(:notice) { @youtube_trademark_b_notice }

      it "notices are created" do
        expect(notice.title).to eq 'Takedown Request regarding Trademark Complaint to YouTube'
        expect(notice.works.length).to eq 1
        expect(notice.infringing_urls.map(&:url)).to match_array(
          %w|https://www.youtube.com/user/ThisChipmunks|
        )
        expect(notice.size).to eq(1)
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 1006
        expect(notice.mark_registration_number).to eq '29350000'
      end

      it "the correct entities are created" do
        expect(notice).to have(3).entity_notice_roles
        expect(notice.sender_name).to eq "Tracy Papagallo, outside counsel"
        expect(notice.principal_name).to eq "Bagdad Productions, LLC"
        expect(notice.recipient_name).to eq "Google, Inc."
        expect(notice.tag_list).to include( 'youtube' )
      end
    end

    context "from the Youtube Trademark-d format" do
      subject(:notice) { @youtube_trademark_d_notice }

      it "notices are created" do
        expect(notice.title).to eq 'Takedown Request regarding Trademark Complaint to YouTube'
        expect(notice.works.length).to eq 1
        expect(notice.infringing_urls.map(&:url)).to match_array(
          %w|http://www.youtube.com/watch?v=iPK
         http://www.youtube.com/watch?v=6HG
         http://www.youtube.com/watch?v=FzH|
        )
        expect(notice.size).to eq(1)
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 1005
        expect(notice.mark_registration_number).to eq '28950000'
      end

      it "the correct entities are created" do
        expect(notice).to have(3).entity_notice_roles
        expect(notice.sender_name).to eq "Jonathan Clucker Rebar, Attorney for Best Example Pest Defense, Inc."
        expect(notice.principal_name).to eq "BEST EXAMPLE PEST DEFENSE, INC."
        expect(notice.recipient_name).to eq "Google, Inc."
        expect(notice.tag_list).to include( 'youtube' )
      end
    end

    context "from the Youtube Defamation format" do
      subject(:notice) { @youtube_defamation_notice }

      it "notices are created" do
        expect(notice.title).to eq 'Takedown Request regarding Defamation Complaint to YouTube'
        expect(notice.works.length).to eq 1
        expect(notice.infringing_urls.map(&:url)).to match_array(
          %w|https://www.youtube.com/watch?v=7uC2cJz0 https://www.youtube.com/watch?v=lRu8rSY|
        )
        expect(notice.size).to eq(1)
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 2000
      end

      it "the correct entities are created" do
        expect(notice).to have(3).entity_notice_roles
        expect(notice.sender_name).to eq "REDACTED"
        expect(notice.principal_name).to eq "REDACTED"
        expect(notice.recipient_name).to eq "Google, Inc."
        expect(notice.tag_list).to include( 'youtube' )
      end
    end

    context "from the primary google reporting format" do
      subject(:notice) { @primary_format_notice }

      it "notices are created" do
        expect(notice.title).to eq 'DMCA (Copyright) Complaint to Google'
        expect(notice.works.length).to eq 2
        expect(notice.infringing_urls.map(&:url)).to match_array(
          [
            "http://infringing.example.com/url_0",
            "http://infringing.example.com/url_1",
            "http://infringing.example.com/url_second_0",
            "http://infringing.example.com/url_second_1"
          ]
        )
        expect(notice.size).to eq(1)
        expect(notice.topics.pluck(:name)).to include('Foobar')
        expect(upload_contents(notice.original_documents.first)).to eq File.read(
          'spec/support/example_files/original_notice_source.txt'
        )
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 1000
        expect(notice.size).to eq(1)
        expect(upload_contents(notice.supporting_documents.first)).to eq File.read(
          'spec/support/example_files/original.jpg'
        )
      end

      it "the correct entities are created" do
        expect(notice).to have(4).entity_notice_roles
        expect(notice.sender_name).to eq "JG Wentworth Associates"
        expect(notice.attorney_name).to eq "John Wentworth"
        expect(notice.principal_name).to eq "Kundan Singh"
        expect(notice.recipient_name).to eq "Google, Inc."
      end
    end

    context "from the secondary google reporting format" do
      subject(:notice) { @secondary_dmca_notice }

      it "a dmca notice is created" do
        expect(notice.title).to eq 'Secondary Google DMCA Import'
        expect(notice.works.length).to eq 1
        expect(notice.infringing_urls.map(&:url)).to match_array(
          %w|http://www.example.com/unstoppable.html
  http://www.example.com/unstoppable_2.html
  http://www.example.com/unstoppable_3.html|
        )
        expect(notice.size).to eq(1)
        expect(notice.topics.pluck(:name)).to include('Foobar')
        expect(upload_contents(notice.original_documents.first)).to eq File.read(
          'spec/support/example_files/secondary_dmca_notice_source.html'
        )
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 1001
        expect(notice.size).to eq(1)
        expect(upload_contents(notice.supporting_documents.first)).to eq File.read(
          'spec/support/example_files/secondary_dmca_notice_source-2.html'
        )
      end
    end

    context "from the secondary other format" do
      subject(:notice) { @secondary_other_notice }

      it "an other notice is created" do
        expect(notice.title).to eq 'Secondary Google Other Import'
        expect(notice.works.length).to eq 1
        expect(notice.infringing_urls.map(&:url)).to match_array(
          %w|http://www.example.com/asdfasdf
          http://www.example.com/infringing|
        )
        expect(notice.size).to eq(1)
        expect(notice.topics.pluck(:name)).to include('Foobar')
        expect(upload_contents(notice.original_documents.first)).to eq File.read(
          'spec/support/example_files/secondary_other_notice_source.html'
        )
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to eq 1002
        expect(notice.size).to eq(1)
        expect(upload_contents(notice.supporting_documents.first)).to eq File.read(
          'spec/support/example_files/secondary_other_notice_source-2.html'
        )
      end
    end

    context "from the twitter format" do
      subject(:notice) { @twitter_notice }

      it "a notice is created" do
        expect(notice.title).to eq 'Twitter Import'
        expect(notice.works.length).to eq 2
        expect(notice.infringing_urls.map(&:url)).to match_array([
          'https://twitter.com/NoMatter/status/12345',
          'https://twitter.com/NoMatter/status/4567',
        ])
        expect(notice.size).to eq(1)
        expect(notice.topics.pluck(:name)).to include('Foobar')
        expect(upload_contents(notice.original_documents.first)).to eq File.read(
          'spec/support/example_files/original_twitter_notice_source.txt'
        )
        expect(notice.action_taken).to eq ''
        expect(notice.submission_id).to be_nil
        expect(notice.size).to eq(1)
        expect(upload_contents(notice.supporting_documents.first)).to eq File.read(
          'spec/support/example_files/original_twitter_notice_source.html'
        )
      end
    end

    context "from a google notice without data" do
      subject(:notice) { @primary_notice_without_data }

      it "a notice is created and entity info is recovered from the file" do
        expect(notice.title).to eq 'Untitled'
        expect(notice.works.length).to eq 2
        expect(notice.size).to eq(1)
        expect(notice.entities.map(&:name)).to match_array(
          ["Copyright Owner LLC", "Google, Inc.", "Joe Schmoe"]
        )
        expect(upload_contents(notice.original_documents.first)).to eq File.read(
          'spec/support/example_files/original_notice_source_2.txt'
        )
        expect(notice.action_taken).to eq ''
      end
    end

    private

    def upload_contents(file_upload)
      File.read(file_upload.file.path)
    end
  end
end
