json.array!(@tasks) do |task|
  json.extract! task, :id, :name, :job_type, :status, :options, :every, :at
  json.url task_url(task, format: :json)
end
