json.id @assistant.id
json.name @assistant.name
json.description @assistant.description
json.created_at @assistant.created_at.to_i
json.updated_at @assistant.updated_at.to_i
json.documents_count @assistant.documents.count
json.responses_count @assistant.responses.count
json.connected_inboxes do
  json.array! @assistant.inboxes do |inbox|
    json.id inbox.id
    json.name inbox.name
  end
end
json.config @assistant.config || {}
json.response_guidelines @assistant.response_guidelines || []
json.guardrails @assistant.guardrails || []

