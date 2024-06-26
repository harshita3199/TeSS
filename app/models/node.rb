class Node < ApplicationRecord
  MEMBER_STATUS = ['Member', 'Observer']
  COUNTRIES = JSON.parse(File.read(File.join(Rails.root, 'config', 'data', 'countries.json')))

  include PublicActivity::Common
  include LogParameterChanges
  include Searchable

  extend FriendlyId
  friendly_id :name, use: :slugged

  belongs_to :user

  has_many :staff, class_name: 'StaffMember', dependent: :destroy
  has_many :training_coordinators, -> { training_coordinators }, class_name: 'StaffMember'

  has_many :content_providers, dependent: :nullify
  has_many :provider_materials, through: :content_providers, source: :materials
  has_many :provider_events, through: :content_providers, source: :events

  has_many :node_links, dependent: :destroy
  has_many :materials, through: :node_links, source: :resource, source_type: 'Material'
  has_many :events, through: :node_links, source: :resource, source_type: 'Event'

  accepts_nested_attributes_for :staff, allow_destroy: true

  clean_array_fields(:carousel_images) #, :institutions

  validates :name, presence: true, uniqueness: true
  validates :home_page, format: { with: URI.regexp }, if: Proc.new { |a| a.home_page.present? }
  validates :country_code, inclusion: { in: COUNTRIES.keys, allow_blank: true }
  # validate :has_training_coordinator

  alias_attribute(:title, :name)

  if TeSS::Config.solr_enabled
    # :nocov:
    searchable do
      string :name
      string :sort_title do
        name.downcase.gsub(/^(an?|the) /, '')
      end
      text :name
      string :country_code
      text :staff do
        staff.map(&:name)
      end
      string :member_status
      time :created_at
      time :updated_at
      integer :user_id # Used for shadowbans
    end
    # :nocov:
  end

  def related_events
    Event.where(id: provider_event_ids | event_ids)
  end

  def related_materials
    Material.where(id: provider_material_ids | material_ids)
  end

  def self.load_from_hash(hash, verbose: false)
    hash["nodes"].map do |node_data|
      node = Node.find_or_initialize_by(name: node_data["name"])
      puts "#{node.new_record? ? 'Creating' : 'Updating'}: #{node_data['name']}" if verbose
      staff_data = node_data.delete('staff')
      node.attributes = node_data
      node.user ||= User.get_default_user

      node.staff = []
      staff_data.each do |staff_member_data|
        node.staff.build(staff_member_data)
      end

      if node.save
        puts 'Success' if verbose
      elsif verbose
        puts 'Failure:'
        node.errors.full_messages.each { |msg|  puts " * #{msg}" }
      end
      puts if verbose

      node
    end
  end

  def self.facet_fields
    %w( member_status )
  end

  private

  def has_training_coordinator
    unless staff.select { |s| s.role == StaffMember::TRAINING_COORDINATOR_ROLE }.any?
      errors.add(:base, 'Requires at least one training coordinator to be defined')
    end
  end

end
