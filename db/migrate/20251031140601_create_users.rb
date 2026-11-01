# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :entity_id
      t.text :name, null: false
      t.text :email, null: false
      t.text :password_digest, null: false
      t.text :access_role, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true

    add_check_constraint :users,
                         "(access_role = 'hr' AND entity_id IS NOT NULL) OR " \
                         "(access_role = 'admin' AND entity_id IS NULL)",
                         name: "users_entity_id_matches_access_role"
  end
end
