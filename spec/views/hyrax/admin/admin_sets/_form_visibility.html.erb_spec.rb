require 'spec_helper'

RSpec.describe 'hyrax/admin/admin_sets/_form_visibility.html.erb', type: :view do
  let(:admin_set) { create(:admin_set) }
  let(:permission_template) { Hyrax::PermissionTemplate.find_or_create_by(admin_set_id: admin_set.id) }
  before do
    @form = Hyrax::Forms::AdminSetForm.new(admin_set, permission_template)
    render
  end
  it "has the form" do
    expect(rendered).to have_selector('#visibility input[type=radio][name="permission_template[release_period]"][value=now]')
    expect(rendered).to have_selector('#visibility input[type=radio][name="permission_template[release_period]"][value=fixed]')
    expect(rendered).to have_selector('#visibility input[type=radio][name="permission_template[release_varies]"][value=before]')
    expect(rendered).to have_selector('#visibility input[type=radio][name="permission_template[release_varies]"][value=embargo]')
    expect(rendered).to have_selector('#visibility select[name="permission_template[release_embargo]"]')
    expect(rendered).to have_selector('#visibility input[type=date][name="permission_template[release_date]"]')
    expect(rendered).to have_selector('#visibility input[type=radio][name="permission_template[visibility]"][value=open]')
    expect(rendered).to have_selector('#visibility input[type=radio][name="permission_template[visibility]"][value=authenticated]')
    expect(rendered).to have_selector('#visibility input[type=radio][name="permission_template[visibility]"][value=restricted]')
  end
end
