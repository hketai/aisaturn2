json.id @scenario.id
json.title @scenario.title
json.description @scenario.description
json.instruction @scenario.instruction
json.enabled @scenario.enabled
json.tools @scenario.tools || []
json.created_at @scenario.created_at.to_i
json.updated_at @scenario.updated_at.to_i
json.assistant do
  json.id @scenario.assistant.id
  json.name @scenario.assistant.name
end

