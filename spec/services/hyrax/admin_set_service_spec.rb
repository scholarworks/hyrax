require 'spec_helper'

RSpec.describe Hyrax::AdminSetService do
  let(:controller) { ::CatalogController.new }
  let(:context) do
    double(current_ability: Ability.new(user),
           repository: controller.repository,
           blacklight_config: controller.blacklight_config)
  end
  let(:service) { described_class.new(context) }
  let(:user) { create(:user) }

  describe "#search_results" do
    subject { service.search_results(access) }
    let!(:as1) { create(:admin_set, :public, title: ['foo']) }
    let!(:as2) { create(:admin_set, :public, title: ['bar']) }
    let!(:as3) { create(:admin_set, edit_users: [user.user_key], title: ['baz']) }
    before do
      create(:collection, :public) # this should never be returned.
    end

    context "with read access" do
      let(:access) { :read }
      it "returns three admin sets" do
        expect(subject.map(&:id)).to match_array [as1.id, as2.id, as3.id]
      end
    end

    context "with edit access" do
      let(:access) { :edit }
      it "returns one admin set" do
        expect(subject.map(&:id)).to match_array [as3.id]
      end
    end
  end

  context "with injection" do
    let(:service) { described_class.new(context, search_builder) }
    subject { service.search_results(access) }
    let(:access) { :edit }
    let(:search_builder) { double(new: search_builder_instance) }
    let(:search_builder_instance) { double }

    it "calls the injected search builder" do
      expect(search_builder_instance).to receive(:reverse_merge).and_return({})
      subject
    end
  end

  describe '#search_results_with_work_count' do
    let(:access) { :read }
    subject { service.search_results_with_work_count(access) }
    let(:documents) { [doc1, doc2, doc3] }
    let(:doc1) { SolrDocument.new(id: 'xyz123') }
    let(:doc2) { SolrDocument.new(id: 'yyx123') }
    let(:doc3) { SolrDocument.new(id: 'zxy123') }
    let(:connection) { instance_double(RSolr::Client) }
    let(:results) do
      { 'facet_counts' =>
        {
          'facet_fields' =>
            {
              'isPartOf_ssim' => [doc1.id, 8, doc2.id, 2]
            }
        } }
    end

    before do
      allow(service).to receive(:search_results).and_return(documents)
      allow(ActiveFedora::SolrService.instance).to receive(:conn).and_return(connection)
      allow(connection).to receive(:get).with("select", params: { fq: "{!terms f=isPartOf_ssim}xyz123,yyx123,zxy123",
                                                                  "facet.field" => "isPartOf_ssim" }).and_return(results)
    end

    it "returns rows with document in the first column and count in the second column" do
      expect(subject).to eq [[doc1, 8], [doc2, 2], [doc3, nil]]
    end
  end

  describe "#select_options" do
    context "with permission_template visibility" do
      subject { service.select_options }
      let(:solr_doc1) { instance_double(SolrDocument, id: '123', to_s: 'Public Set') }
      let(:solr_doc2) { instance_double(SolrDocument, id: '345', to_s: 'Private Set') }
      let(:solr_doc3) { instance_double(SolrDocument, id: '567', to_s: 'No Visibility Set') }
      let!(:permission_template1) { create(:permission_template, admin_set_id: '123', visibility: 'open') }
      let!(:permission_template2) { create(:permission_template, admin_set_id: '345', visibility: 'restricted') }
      let!(:permission_template3) { create(:permission_template, admin_set_id: '567') }

      before do
        allow(service).to receive(:search_results)
          .with(:read)
          .and_return([solr_doc1, solr_doc2, solr_doc3])
      end

      it do
        is_expected.to eq [['Public Set', '123', { 'data-visibility' => 'open' }],
                           ['Private Set', '345', { 'data-visibility' => 'restricted' }],
                           ['No Visibility Set', '567', { 'data-visibility' => nil }]]
      end
    end

    context "with no permission_template" do
      context "with default (read) access" do
        subject { service.select_options }
        let(:solr_doc1) { instance_double(SolrDocument, id: '123', to_s: 'foo') }
        let(:solr_doc2) { instance_double(SolrDocument, id: '234', to_s: 'bar') }
        let(:solr_doc3) { instance_double(SolrDocument, id: '345', to_s: 'baz') }

        before do
          allow(service).to receive(:search_results)
            .with(:read)
            .and_return([solr_doc1, solr_doc2, solr_doc3])
        end

        it do
          is_expected.to eq [['foo', '123', { "data-visibility" => nil }],
                             ['bar', '234', { "data-visibility" => nil }],
                             ['baz', '345', { "data-visibility" => nil }]]
        end
      end

      context "with explicit edit access" do
        subject { service.select_options(:edit) }
        let(:solr_doc) { instance_double(SolrDocument, id: '123', to_s: 'baz') }

        before do
          allow(service).to receive(:search_results).with(:edit).and_return([solr_doc])
        end

        it { is_expected.to eq [['baz', '123', { "data-visibility" => nil }]] }
      end
    end
  end
end
