Sequel.migration do
  up do
    alter_table :users do
      set_column_default :private_maps_enabled, true
    end
  end
  down do
    alter_table :users do
      set_column_default :private_maps_enabled, false
    end
  end
end
