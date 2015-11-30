json.array!(@workflows) do |workflow|
  json.extract! workflow, :id, :title, :description, :user_id, :workflow_content
  json.url workflow_url(workflow, format: :json)
end
