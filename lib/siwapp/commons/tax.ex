defmodule Siwapp.Commons.Tax do
  use Ecto.Schema

  import Ecto.Changeset

  alias Siwapp.Invoices.Item

  @fields [:name, :value, :enabled, :default, :deleted_at]

  schema "taxes" do
    field :name, :string
    field :value, :integer
    field :enabled, :boolean, default: true
    field :default, :boolean, default: false
    field :deleted_at, :utc_datetime
    many_to_many :items, Item, join_through: "items_taxes"
  end

  def changeset(tax, attrs \\ %{}) do
    tax
    |> cast(attrs, @fields)
    |> validate_required([:name, :value])
    |> validate_length(:name, max: 50)
  end
end
