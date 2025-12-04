namespace :shopify_db do
  desc 'Create Shopify database'
  task create: :environment do
    ActiveRecord::Base.establish_connection(:shopify)
    ActiveRecord::Tasks::DatabaseTasks.create_current
    puts "✅ Shopify database created"
  rescue StandardError => e
    puts "❌ Failed to create Shopify database: #{e.message}"
  end
  
  desc 'Run Shopify migrations'
  task migrate: :environment do
    ActiveRecord::Base.establish_connection(:shopify)
    ActiveRecord::Tasks::DatabaseTasks.migrate
    puts "✅ Shopify migrations completed"
  rescue StandardError => e
    puts "❌ Failed to run Shopify migrations: #{e.message}"
  end
  
  desc 'Rollback Shopify migrations'
  task rollback: :environment do
    ActiveRecord::Base.establish_connection(:shopify)
    ActiveRecord::Tasks::DatabaseTasks.rollback
    puts "✅ Shopify migrations rolled back"
  rescue StandardError => e
    puts "❌ Failed to rollback Shopify migrations: #{e.message}"
  end
  
  desc 'Test Shopify database connection'
  task test_connection: :environment do
    begin
      ActiveRecord::Base.establish_connection(:shopify)
      connection = ActiveRecord::Base.connection
      
      puts "✅ Database connection successful!"
      puts "Database: #{connection.current_database}"
      puts "PostgreSQL version: #{connection.select_value('SELECT version()')}"
      
      # pgvector extension kontrolü
      if connection.extension_enabled?('vector')
        puts "✅ pgvector extension enabled"
      else
        puts "⚠️  pgvector extension NOT enabled"
        puts "Run: CREATE EXTENSION vector;"
      end
      
      # Test query
      result = connection.select_value('SELECT 1')
      puts "✅ Test query successful: #{result}"
      
    rescue StandardError => e
      puts "❌ Connection failed: #{e.message}"
      puts e.backtrace.first(5)
    end
  end
end

