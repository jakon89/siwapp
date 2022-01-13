defmodule Siwapp.Invoices.Invoice do
  @moduledoc """
  Invoice
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Siwapp.InvoiceHelper

  alias Siwapp.Commons.Series
  alias Siwapp.Customers.Customer
  alias Siwapp.Invoices.Item
  alias Siwapp.RecurringInvoices.RecurringInvoice

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: binary() | nil,
          identification: binary() | nil,
          email: binary() | nil,
          contact_person: binary() | nil,
          net_amount: non_neg_integer(),
          gross_amount: non_neg_integer(),
          paid_amount: non_neg_integer(),
          draft: boolean(),
          paid: boolean(),
          sent_by_email: boolean(),
          number: pos_integer() | nil,
          issue_date: Date.t() | nil,
          due_date: Date.t() | nil,
          failed: boolean(),
          deleted_number: pos_integer() | nil,
          currency: binary() | nil,
          invoicing_address: binary() | nil,
          shipping_address: binary() | nil,
          notes: binary() | nil,
          terms: binary() | nil,
          deleted_at: DateTime.t() | nil,
          meta_attributes: map() | nil,
          series_id: pos_integer() | nil,
          customer_id: pos_integer(),
          recurring_invoice_id: pos_integer() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @fields [
    :name,
    :identification,
    :email,
    :contact_person,
    :net_amount,
    :gross_amount,
    :paid_amount,
    :draft,
    :paid,
    :sent_by_email,
    :number,
    :issue_date,
    :due_date,
    :failed,
    :deleted_number,
    :currency,
    :invoicing_address,
    :shipping_address,
    :notes,
    :terms,
    :deleted_at,
    :meta_attributes,
    :series_id,
    :customer_id,
    :recurring_invoice_id
  ]

  schema "invoices" do
    field :identification, :string
    field :name, :string
    field :email, :string
    field :contact_person, :string
    field :net_amount, :integer, default: 0
    field :gross_amount, :integer, default: 0
    field :paid_amount, :integer, default: 0
    field :taxes_amounts, :map, virtual: true, default: %{}
    field :draft, :boolean, default: false
    field :paid, :boolean, default: false
    field :sent_by_email, :boolean, default: false
    field :number, :integer
    field :issue_date, :date
    field :due_date, :date
    field :failed, :boolean, default: false
    field :deleted_number, :integer
    field :currency, :string
    field :invoicing_address, :string
    field :shipping_address, :string
    field :notes, :string
    field :terms, :string
    field :deleted_at, :utc_datetime
    field :meta_attributes, :map, default: %{}
    belongs_to :series, Series
    belongs_to :customer, Customer
    belongs_to :recurring_invoice, RecurringInvoice
    has_many :items, Item, on_replace: :delete

    timestamps()
  end

  def changeset(invoice, attrs \\ %{}) do
    invoice
    |> cast(attrs, @fields)
    |> cast_assoc(:items)
    |> find_customer_or_new()
    |> validate_draft_enablement()
    |> validate_required_draft()
    |> unique_constraint([:series_id, :number])
    |> unique_constraint([:series_id, :deleted_number])
    |> foreign_key_constraint(:series_id)
    |> foreign_key_constraint(:customer_id)
    |> foreign_key_constraint(:recurring_invoice_id)
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
    |> validate_length(:name, max: 100)
    |> validate_length(:identification, max: 50)
    |> validate_length(:email, max: 100)
    |> validate_length(:contact_person, max: 100)
    |> validate_length(:currency, max: 100)
    |> calculate()
  end

  # you can't convert an existing invoice to draft
  defp validate_draft_enablement(changeset) do
    if get_field(changeset, :id) != nil and
         fetch_field(changeset, :draft) == {:changes, true} do
      add_error(changeset, :draft, "can't be enabled, invoice is not new")
    else
      changeset
    end
  end

  # When draft there are few restrictions
  defp validate_required_draft(changeset) do
    if get_field(changeset, :draft) do
      changeset
    else
      changeset
      |> validate_required([:series_id, :issue_date])
      |> assoc_constraint(:customer)
    end
  end

  @doc """
  Performs the totals calculations for net_amount, taxes_amounts and gross_amount fields.
  """
  @spec calculate(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def calculate(changeset) do
    changeset
    |> set_net_amount()
    |> set_taxes_amounts()
    |> set_gross_amount()
  end

  defp set_net_amount(changeset) do
    total_net_amount =
      get_field(changeset, :items)
      |> Enum.map(& &1.net_amount)
      |> Enum.sum()
      |> round()

    put_change(changeset, :net_amount, total_net_amount)
  end

  defp set_taxes_amounts(changeset) do
    total_taxes_amounts =
      get_field(changeset, :items)
      |> Enum.map(& &1.taxes_amount)
      |> Enum.reduce(%{}, &Map.merge(&1, &2, fn _, v1, v2 -> v1 + v2 end))

    put_change(changeset, :taxes_amounts, total_taxes_amounts)
  end

  defp set_gross_amount(changeset) do
    net_amount = get_field(changeset, :net_amount)

    taxes_amount =
      get_field(changeset, :taxes_amounts)
      |> Map.values()
      |> Enum.sum()

    put_change(changeset, :gross_amount, round(net_amount + taxes_amount))
  end
end
