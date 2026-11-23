# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-law_firm"
  s.version     = "1.0.0"
  s.authors     = "Law Offices of Villanueva, Dorin & Lozano"
  s.summary     = "VDL Dashboard law firm customizations"
  s.description = "Philippine law firm features for the VDL Dashboard, kept apart from OpenProject core"
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
