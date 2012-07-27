migration 3, :create_friendships do
  up do
    create_table :friendships do
      column :id, Integer, :serial => true
      
    end
  end

  down do
    drop_table :friendships
  end
end
