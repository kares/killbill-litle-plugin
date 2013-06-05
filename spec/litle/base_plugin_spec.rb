require 'spec_helper'

describe Killbill::Litle::PaymentPlugin do
  before(:each) do
    Dir.mktmpdir do |dir|
      file = File.new(File.join(dir, 'litle.yml'), "w+")
      file.write(<<-eos)
:litle:
  :merchant_id:
    :USD: 'merchant_id'
  :password: 'password'
# As defined by spec_helper.rb
:database:
  :adapter: 'sqlite3'
  :database: 'test.db'
      eos
      file.close

      @plugin = Killbill::Litle::PaymentPlugin.new
      @plugin.logger = Logger.new(STDOUT)
      @plugin.conf_dir = File.dirname(file)

      # Start the plugin here - since the config file will be deleted
      @plugin.start_plugin
    end
  end

  it 'should start and stop correctly' do
    @plugin.stop_plugin
  end

  it 'should reset payment methods' do
    kb_account_id = '129384'

    @plugin.get_payment_methods(kb_account_id, false, nil).size.should == 0
    verify_pms kb_account_id, 0

    # Create a pm with a kb_payment_method_id
    Killbill::Litle::LitlePaymentMethod.create :kb_account_id => kb_account_id,
                                               :kb_payment_method_id => 'kb-1',
                                               :litle_token => 'litle-1'
    verify_pms kb_account_id, 1

    # Add some in KillBill and reset
    payment_methods = []
    # Random order... Shouldn't matter...
    payment_methods << Killbill::Plugin::Model::PaymentMethodInfoPlugin.new(kb_account_id, 'kb-3', false, 'litle-3')
    payment_methods << Killbill::Plugin::Model::PaymentMethodInfoPlugin.new(kb_account_id, 'kb-2', false, 'litle-2')
    payment_methods << Killbill::Plugin::Model::PaymentMethodInfoPlugin.new(kb_account_id, 'kb-4', false, 'litle-4')
    @plugin.reset_payment_methods kb_account_id, payment_methods
    verify_pms kb_account_id, 4

    # Add a payment method without a kb_payment_method_id
    Killbill::Litle::LitlePaymentMethod.create :kb_account_id => kb_account_id,
                                               :litle_token => 'litle-5'
    @plugin.get_payment_methods(kb_account_id, false, nil).size.should == 5

    # Verify we can match it
    payment_methods << Killbill::Plugin::Model::PaymentMethodInfoPlugin.new(kb_account_id, 'kb-5', false, 'litle-5')
    @plugin.reset_payment_methods kb_account_id, payment_methods
    verify_pms kb_account_id, 5

    @plugin.stop_plugin
  end

  private

  def verify_pms(kb_account_id, size)
    pms = @plugin.get_payment_methods(kb_account_id, false, nil)
    pms.size.should == size
    pms.each do |pm|
      pm.account_id.should == kb_account_id
      pm.is_default.should == false
      pm.external_payment_method_id.should == 'litle-' + pm.payment_method_id.split('-')[1]
    end
  end
end
