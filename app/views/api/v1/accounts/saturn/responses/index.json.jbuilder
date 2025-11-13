json.array! @responses do |response|
  json.id response.id
  json.question response.question
  json.answer response.answer
  json.status response.status
  json.created_at response.created_at.to_i
  json.updated_at response.updated_at.to_i
  json.assistant do
    json.id response.assistant.id
    json.name response.assistant.name
  end
  if response.documentable
    json.document do
      json.id response.documentable.id
      json.name response.documentable.name
    end
  end
end

