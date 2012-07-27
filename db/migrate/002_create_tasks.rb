migration 2, :create_tasks do
  up do
    create_table :tasks do
      column :id, Integer, :serial => true
      
    end
  end

  down do
    drop_table :tasks
  end
end
