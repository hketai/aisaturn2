json.id @document.id
json.name @document.name
json.external_link @document.external_link
json.content @document.content
json.status @document.status
json.created_at @document.created_at.to_i
json.updated_at @document.updated_at.to_i
json.assistant do
  json.id @document.assistant.id
  json.name @document.assistant.name
end
json.metadata @document.metadata || {}

