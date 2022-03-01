defmodule Siwapp.Commons.Tax do
  @moduledoc """
  Tax
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Siwapp.Invoices.Item

  @fields [:name, :value, :enabled, :default]

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          name: binary | nil,
          value: binary | nil,
          enabled: boolean(),
          default: boolean()
        }

  schema "taxes" do
    field :name, :string
    field :value, :integer
    field :enabled, :boolean, default: true
    field :default, :boolean, default: false

    many_to_many :items, Item,
      join_through: "items_taxes",
      on_replace: :delete
  end

  @spec changeset(t(), map) :: Ecto.Changeset.t()
  def changeset(tax, attrs \\ %{}) do
    tax
    |> cast(attrs, @fields)
    |> unique_constraint([:name, :enabled])
    |> validate_required([:name, :value])
    |> validate_length(:name, max: 50)
  end
end
