# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-data_privacy"
  s.version     = "1.0.0"
  s.authors     = "Law Offices of Villanueva, Dorin & Lozano"
  s.summary     = "VDL Dashboard data privacy"
  s.description = "Data Privacy Act (RA 10173) consent records, an audit trail and confidential matters"
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
