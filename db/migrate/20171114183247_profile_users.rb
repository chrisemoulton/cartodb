Sequel.migration do

  up do
    create_table(:profiles_users) do
      foreign_key :profile_id, :profiles, :type=>"uuid", :null=>false, :key=>[:id]
      foreign_key :user_id, :users, :type=>"uuid", :null=>false, :key=>[:id]
    end
  end

  down do
    drop_table :profiles_users
  end

end
