json.id @tool.id
json.slug @tool.slug
json.title @tool.title
json.description @tool.description
json.http_method @tool.http_method
json.endpoint_url @tool.endpoint_url
json.request_template @tool.request_template
json.response_template @tool.response_template
json.auth_type @tool.auth_type
json.auth_config @tool.auth_config || {}
json.param_schema @tool.param_schema || []
json.enabled @tool.enabled
json.created_at @tool.created_at.to_i
json.updated_at @tool.updated_at.to_i

