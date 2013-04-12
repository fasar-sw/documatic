# encoding: utf-8
#!/usr/bin/ruby

require 'rubygems'
require 'ruport'
require 'documatic'


# This usually uses I18n.t() calls on Rails locale files.
#
def prepare_report_label_hash()
  {
    :report_title               => "Funnỹ Ỉnvöìce",
    :date                       => "Date",
    :customer                   => "Customer",
    :phone_main                 => "Phone",
    :phone_fax                  => "Fax",
    :e_mail                     => "e-mail",
    :tax_code                   => "Tax code",
    :vat_registration           => "VAT reg.#",
    :notes_title                => "Notes",
    :copy_watermark             => "( Administrative usage COPY - UTF8 Test )",
    :banking_coordinates        => "Banking Coordinates",

    :company_name               => "Name",
    :company_full_address       => "Address",
    :company_phone_main         => "Phone",
    :company_phone_hq           => "Phone (HQ)",
    :company_phone_fax          => "Fax",
    :company_e_mail             => "e-mail",
    :company_tax_code           => "Tax code",
    :company_vat_registration   => "VAT reg.#",
    :customer_name              => "Name",
    :customer_full_address      => "Address",
    :customer_phone_main        => "Phone",
    :customer_phone_hq          => "Phone (HQ)",
    :customer_phone_fax         => "Fax",
    :customer_e_mail            => "e-mail",
    :customer_tax_code          => "Tax code",
    :customer_vat_registration  => "VAT reg.#",
    :header_object              => "Subject",
    :notes_text                 => "Notes",
    :bank_cin_abicab            => "IBAN Code",
    :bank_cc                    => "",

    :round_quantity             => "Q.ty",
    :le_invoice_row_unit        => "Unit",
    :description                => "Description",
    :unit_cost                  => "Cost",
    :taxable_amount             => "Taxable amount",
    :discount_percent           => "Discount (%)",
    :vat_tax_percent            => "VAT(%)",
    :net_tax                    => "Net Tax",
    :net_amount                 => "Net Amount",
    :sum_cost_x_qty             => "Items cost x q.ty",
    :subtotal                   => "Items subtotal",
    :social_security_cost       => "Soc.Secur.Cost",
    :social_security_amount     => "Soc.Secur.Amount",
    :total_taxable_amount       => "Tot. taxable Amount",
    :total_tax                  => "Total Tax",
    :total                      => "Total",
    :account_wage               => "Account wage",
    :account_wage_amount        => "Account wage",
    :total_expenses             => "Total expenses",
    :grand_total                => "Grand Total",
    :currency_name              => "Currency"
  }
end
# -----------------------------------------------------------------------------


def prepare_report_header_hash()
  {
    :report_title               => "#{DateTime.now.strftime("%Y")}-001",
    :date                       => DateTime.now.strftime("%Y-%m-%d"),
    :company_name               => "ÅẄṦṒḾË Ṕṛöṱêỹñṧ Inc. Corp.",
    :company_full_address       => "7255 Awesome St., Funland, UTF",
    :company_phone_main         => "++01.555.1234.5555",
    :company_phone_hq           => "++01.555.1234.5566",
    :company_phone_fax          => "++01.555.1234.5577",
    :company_e_mail             => "awesome.prot@mydomain.org",
    :company_tax_code           => "01 22 3333 4444",
    :company_vat_registration   => "01 22 3333 4444",
    :customer_name              => "Lebowsky John",
    :customer_full_address      => "1 Dude St., Sharona, MY",
    :customer_phone_main        => "++01.666.7777.8888",
    :customer_phone_hq          => "++01.666.7777.8888",
    :customer_phone_fax         => "",
    :customer_e_mail            => "the.dude@lebowsky.org",
    :customer_tax_code          => "02 33 4444 5555",
    :customer_vat_registration  => "02 33 4444 5555",
    :header_object              => "On-line order #12345",
    :notes_text                 => ["Already payed by VISA", "\n", "Deliver directly to address.", "\n"],
    :bank_name                  => "BigBucks Inc. Glob. Corp.",
    :bank_cc                    => "",
    :bank_cin_abicab            => "USX 123 12345 12345 0000001234567890"
  }
end


def prepare_report_detail()
  column_names = [
    :round_quantity, :le_invoice_row_unit, :description, :unit_cost, :taxable_amount,
    :discount_percent, :vat_tax_percent, :net_tax, :net_amount
  ]
  array_of_raw_data = [
    [3, 'pack', 'milk protein isolate 2 Kg., natural flavour', 50.00, 135.00, 10.0, 20.0, 27.00, 162.00], 
    [5, 'pack', 'milk protein isolate 2 Kg., chocolate flavour', 50.00, 250.00, 0.0, 20.0, 50.00, 300.00], 
    [2, 'pack', 'ultra pro-whey 1 Kg., vanilla flavour', 30.00, 60.00, 0.0, 20.0, 12.00, 72.00], 
  ]

  return Ruport::Data::Table.new( :data => array_of_raw_data, :column_names => column_names )
end


def prepare_summary_hash( data_table, social_security_cost, account_wage, total_expenses,
                          currency_name )
  sum_cost_x_qty          = data_table.sigma( :taxable_amount )
  subtotal                = data_table.sigma( :net_amount )
  social_security_amount  = subtotal * social_security_cost
  total_taxable_amount    = subtotal + social_security_amount
  total_tax               = data_table.sigma { |row| 
    (row.net_amount.to_f + row.net_amount.to_f * social_security_cost.to_f) * (row.vat_tax_percent.to_f / 100.0)
  }
  total                   = total_taxable_amount + total_tax
  account_wage_amount     = total_taxable_amount * account_wage
  grand_total             = total + account_wage_amount + total_expenses

  return {
    :sum_cost_x_qty         => sum_cost_x_qty.to_f,
    :subtotal               => subtotal.to_f,
    :social_security_cost   => social_security_cost.to_f,
    :social_security_amount => social_security_amount.to_f,
    :total_taxable_amount   => total_taxable_amount.to_f,
    :total_tax              => total_tax.to_f,
    :total                  => total.to_f,
    :account_wage           => account_wage.to_f,
    :account_wage_amount    => total_expenses.to_f,
    :total_expenses         => total_expenses.to_f,
    :grand_total            => grand_total.to_f,
    :currency_name          => currency_name
  }
end
# -----------------------------------------------------------------------------


def prepare_report_data_hash( is_internal_copy = false )
  currency_name  = 'Euro'
  currency_short = '€'
                                                  # Demo data setup:
  data_table    = prepare_report_detail()
  computed_sums = prepare_summary_hash(
      data_table,                                 # a Ruport::Data::Table
      0.04,                                       # social_security_cost in floating-point (applied as percentage)
      0.2,                                        # account_wage in floating-point (applied as percentage)
      15.0,                                       # total_expenses (expedition or whatever)
      currency_short
  )
  label_hash    = prepare_report_label_hash()

  result_hash = {                                 # Prepare result hash:
    :is_internal_copy   => is_internal_copy,
    :report_title       => "Demo Invoice #01",
    :report_base_name   => "demo_invoice_01" + (is_internal_copy ? '_copy' : ''),
                                                  # Main data:
    :data_table         => data_table,
    :summary            => computed_sums,
    :label_hash         => label_hash,              # (This should be already translated and containing all the required label symbols)
    :currency_name      => currency_name,
    :currency_short     => currency_short,          # (currency display symbol or short name)
    :grouping_total     => computed_sums[:grand_total].to_s,
    :privacy_statement  => "<b>Privacy notice</b> - According to the latest laws regarding Personal Privacy, we inform you that any personal data acquired before and during this business transaction will be kept and used only for our own fiscal administration purposes. You have the right to request directly to us, any time, the deletion or the update of the stored data itself."
  }

  result_hash
end
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------


filename = "invoice_#{ DateTime.now.strftime("%Y%m%d_%H%M%S") }.odt"
options = {
  :template_file    => "invoice_en.odt",
  :output_file      => filename,
  :current_datetime => DateTime.now.strftime("[%Y-%m-%d, %H:%M:%S]")
}.merge!( prepare_report_header_hash() )
                                            # == Render layout & save processed copy:
Documatic::OpenDocumentText::Template.process_template(
    :options => Ruport::Controller::Options.new( options ), # report header + rendering options
    :data => prepare_report_data_hash( true )               # actual data table + label translations; is_internal_copy = true
)
# -----------------------------------------------------------------------------
