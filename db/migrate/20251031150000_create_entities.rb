# frozen_string_literal: true

class CreateEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :entities do |t|
      t.references :company, null: false, foreign_key: true
      t.text :name, null: false
      t.text :country, null: false
      t.text :currency, null: false

      t.timestamps
    end

    add_index :entities, %i[company_id id], unique: true, name: "index_entities_on_company_id_and_id"

    add_foreign_key :users, :entities, column: %i[company_id entity_id], primary_key: %i[company_id id]
  end
end
