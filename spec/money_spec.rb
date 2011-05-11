# encoding: utf-8

require "spec_helper"

describe Money do

  describe "#new" do
    it "rounds the given cents to an integer" do
      Money.new(1.00, "USD").cents.should == 1
      Money.new(1.01, "USD").cents.should == 1
      Money.new(1.50, "USD").cents.should == 2
    end

    it "is associated to the singleton instance of Bank::VariableExchange by default" do
      Money.new(0).bank.should be_equal(Money::Bank::VariableExchange.instance)
    end

  end

  describe "#cents" do
    it "returns the amount of cents passed to the constructor" do
      Money.new(200_00, "USD").cents.should == 200_00
    end

    it "stores cents as an integer regardless of what is passed into the constructor" do
      [ Money.new(100), 1.to_money, 1.00.to_money, BigDecimal('1.00').to_money ].each do |m|
        m.cents.should == 100
        m.cents.should be_an_instance_of(Fixnum)
      end
    end
  end

  describe "#dollars" do
    it "gets cents as dollars" do
      Money.new_with_dollars(1).should == Money.new(100)
      Money.new_with_dollars(1, "USD").should == Money.new(100, "USD")
      Money.new_with_dollars(1, "EUR").should == Money.new(100, "EUR")
    end

    it "should respect :subunit_to_unit currency property" do
      Money.new(1_00,  "USD").dollars.should == 1
      Money.new(1_000, "TND").dollars.should == 1
      Money.new(1,     "CLP").dollars.should == 1
    end

    it "should not loose precision" do
      Money.new(100_37).dollars.should == 100.37
      Money.new_with_dollars(100.37).dollars.should == 100.37
    end
  end

  specify "#currency returns the currency passed to the constructor" do
    Money.new(200_00, "USD").currency.should == Money::Currency.new("USD")
  end

  specify "#currency_string returns the iso_code of the currency object" do
    Money.new(200_00, "USD").currency_as_string.should == Money::Currency.new("USD").to_s
    Money.new(200_00, "USD").currency_as_string.should == "USD"
    Money.new(200_00, "EUR").currency_as_string.should == "EUR"
    Money.new(200_00, "YEN").currency_as_string.should == "YEN"
  end

  specify "#currency_string= set the currency object using the provided string" do
    obj = Money.new(200_00, "USD")
    obj.currency_as_string = "EUR"
    obj.currency.should == Money::Currency.new("EUR")
    obj.currency_as_string = "YEN"
    obj.currency.should == Money::Currency.new("YEN")
    obj.currency_as_string = "USD"
    obj.currency.should == Money::Currency.new("USD")
  end


  specify "#exchange_to exchanges the amount via its exchange bank" do
    money = Money.new(100_00, "USD")
    money.bank.should_receive(:exchange_with).with(Money.new(100_00, Money::Currency.new("USD")), Money::Currency.new("EUR")).and_return(Money.new(200_00, Money::Currency.new('EUR')))
    money.exchange_to("EUR")
  end

  specify "#exchange_to exchanges the amount properly" do
    money = Money.new(100_00, "USD")
    money.bank.should_receive(:exchange_with).with(Money.new(100_00, Money::Currency.new("USD")), Money::Currency.new("EUR")).and_return(Money.new(200_00, Money::Currency.new('EUR')))
    money.exchange_to("EUR").should == Money.new(200_00, "EUR")
  end

  specify "#hash should return the same value for equal objects" do
    Money.new(1_00, :eur).hash.should == Money.new(1_00, :eur).hash
    Money.new(2_00, :usd).hash.should == Money.new(2_00, :usd).hash
    Money.new(1_00, :eur).hash.should_not == Money.new(2_00, :eur).hash
    Money.new(1_00, :eur).hash.should_not == Money.new(1_00, :usd).hash
    Money.new(1_00, :eur).hash.should_not == Money.new(2_00, :usd).hash
  end

  specify "#hash can be used to return the intersection of Money object arrays" do
    intersection = [Money.new(1_00, :eur), Money.new(1_00, :usd)] & [Money.new(1_00, :eur)]
    intersection.should == [Money.new(1_00, :eur)]
  end


  specify "Money.to_s works" do
    Money.new(10_00).to_s.should == "10.00"
    Money.new(400_08).to_s.should == "400.08"
    Money.new(-237_43).to_s.should == "-237.43"
  end

  specify "Money.to_s should respect :subunit_to_unit currency property" do
    Money.new(10_00, "BHD").to_s.should == "1.000"
    Money.new(10_00, "CNY").to_s.should == "10.00"
  end

  specify "Money.to_s shouldn't have decimal when :subunit_to_unit is 1" do
    Money.new(10_00, "CLP").to_s.should == "1000"
  end

  specify "Money.to_s should work with :subunit_to_unit == 5" do
    Money.new(10_00, "MGA").to_s.should == "200.0"
  end

  specify "Money.to_s should respect :decimal_mark" do
    Money.new(10_00, "BRL").to_s.should == "10,00"
  end

  specify "Money.to_f works" do
    Money.new(10_00).to_f.should == 10.0
  end

  specify "Money.to_f should respect :subunit_to_unit currency property" do
    Money.new(10_00, "BHD").to_f.should == 1.0
  end

  specify "#symbol works as documented" do
    currency = Money::Currency.new("EUR")
    currency.should_receive(:symbol).and_return("€")
    Money.empty(currency).symbol.should == "€"

    currency = Money::Currency.new("EUR")
    currency.should_receive(:symbol).and_return(nil)
    Money.empty(currency).symbol.should == "¤"
  end

  {
    :delimiter => { :default => ",", :other => "." },
    :separator => { :default => ".", :other => "," }
  }.each do |method, options|
    describe "##{method}" do
      context "without I18n" do
        it "works as documented" do
          Money.empty("USD").send(method).should == options[:default]
          Money.empty("EUR").send(method).should == options[:default]
          Money.empty("BRL").send(method).should == options[:other]
        end
      end

      if Object.const_defined?("I18n")
        context "with I18n" do
          before :all do
            reset_i18n
            store_number_formats(:en, method => options[:default])
            store_number_formats(:de, method => options[:other])
          end

          it "looks up #{method} for current locale" do
            I18n.locale = :en
            Money.empty("USD").send(method).should == options[:default]
            I18n.locale = :de
            Money.empty("USD").send(method).should == options[:other]
          end

          it "fallbacks to default behaviour for missing translations" do
            I18n.locale = :de
            Money.empty("USD").send(method).should == options[:other]
            I18n.locale = :fr
            Money.empty("USD").send(method).should == options[:default]
          end

          after :all do
            reset_i18n
          end
        end
      else
        puts "can't test ##{method} with I18n because it isn't loaded"
      end
    end
  end

  describe "#format" do
    it "returns the monetary value as a string" do
      Money.ca_dollar(100).format.should == "$1.00"
    end

    it "should respect :subunit_to_unit currency property" do
      Money.new(10_00, "BHD").format.should == "ب.د1.000"
    end

    it "doesn't display a decimal when :subunit_to_unit is 1" do
      Money.new(10_00, "CLP").format.should == "$1.000"
    end

    it "respects the delimiter and separator defaults" do
      one_thousand = Proc.new do |currency|
        Money.new(1000_00, currency).format
      end

      # Pounds
      one_thousand["GBP"].should == "£1,000.00"

      # Dollars
      one_thousand["USD"].should == "$1,000.00"
      one_thousand["CAD"].should == "$1,000.00"
      one_thousand["AUD"].should == "$1,000.00"
      one_thousand["NZD"].should == "$1,000.00"
      one_thousand["ZWD"].should == "$1,000.00"

      # Yen
      one_thousand["JPY"].should == "¥1,000.00"
      one_thousand["CNY"].should == "¥10,000.0"

      # Euro
      one_thousand["EUR"].should == "€1,000.00"

      # Rupees
      one_thousand["INR"].should == "₨1,000.00"
      one_thousand["NPR"].should == "₨1,000.00"
      one_thousand["SCR"].should == "₨1,000.00"
      one_thousand["LKR"].should == "₨1,000.00"

      # Brazilian Real
      one_thousand["BRL"].should == "R$ 1.000,00"

      # Other
      one_thousand["SEK"].should == "kr1,000.00"
      one_thousand["GHC"].should == "₵1,000.00"
    end

    describe "if the monetary value is 0" do
      before :each do
        @money = Money.us_dollar(0)
      end

      it "returns 'free' when :display_free is true" do
        @money.format(:display_free => true).should == 'free'
      end

      it "returns '$0.00' when :display_free is false or not given" do
        @money.format.should == '$0.00'
        @money.format(:display_free => false).should == '$0.00'
        @money.format(:display_free => nil).should == '$0.00'
      end

      it "returns the value specified by :display_free if it's a string-like object" do
        @money.format(:display_free => 'gratis').should == 'gratis'
      end
    end

    specify "#format(:with_currency => true) works as documented" do
      Money.ca_dollar(100).format(:with_currency => true).should == "$1.00 CAD"
      Money.us_dollar(85).format(:with_currency => true).should == "$0.85 USD"
    end

    # DEPRECATED: v3.5.0
    specify "#format(:with_currency) works as documented" do
      Money.ca_dollar(100).format(:with_currency).should == "$1.00 CAD"
      Money.us_dollar(85).format(:with_currency).should == "$0.85 USD"
    end

    specify "#format(:no_cents => true) works as documented" do
      Money.ca_dollar(100).format(:no_cents => true).should == "$1"
      Money.ca_dollar(599).format(:no_cents => true).should == "$5"
      Money.ca_dollar(570).format(:no_cents => true, :with_currency => true).should == "$5 CAD"
      Money.ca_dollar(39000).format(:no_cents => true).should == "$390"
    end

    specify "#format(:no_cents => true) should respect :subunit_to_unit currency property" do
      Money.new(10_00, "BHD").format(:no_cents => true).should == "ب.د1"
    end

    # DEPRECATED: v3.5.0
    specify "#format(:no_cents) works as documented" do
      Money.ca_dollar(100).format(:no_cents).should == "$1"
      Money.ca_dollar(599).format(:no_cents).should == "$5"
      Money.ca_dollar(570).format(:no_cents, :with_currency).should == "$5 CAD"
      Money.ca_dollar(39000).format(:no_cents).should == "$390"
    end

    # DEPRECATED: v3.5.0
    specify "#format(:no_cents) should respect :subunit_to_unit currency property" do
      Money.new(10_00, "BHD").format(:no_cents).should == "ب.د1"
    end

    specify "#format(:symbol => a symbol string) uses the given value as the money symbol" do
      Money.new(100, "GBP").format(:symbol => "£").should == "£1.00"
    end

    specify "#format(:symbol => true) returns symbol based on the given currency code" do
      one = Proc.new do |currency|
        Money.new(100, currency).format(:symbol => true)
      end

      # Pounds
      one["GBP"].should == "£1.00"

      # Dollars
      one["USD"].should == "$1.00"
      one["CAD"].should == "$1.00"
      one["AUD"].should == "$1.00"
      one["NZD"].should == "$1.00"
      one["ZWD"].should == "$1.00"

      # Yen
      one["JPY"].should == "¥1.00"
      one["CNY"].should == "¥10.0"

      # Euro
      one["EUR"].should == "€1.00"

      # Rupees
      one["INR"].should == "₨1.00"
      one["NPR"].should == "₨1.00"
      one["SCR"].should == "₨1.00"
      one["LKR"].should == "₨1.00"

      # Brazilian Real
      one["BRL"].should == "R$ 1,00"

      # Other
      one["SEK"].should == "kr1.00"
      one["GHC"].should == "₵1.00"
    end

    specify "#format(:symbol => true) returns $ when currency code is not recognized" do
      currency = Money::Currency.new("EUR")
      currency.should_receive(:symbol).and_return(nil)
      Money.new(100, currency).format(:symbol => true).should == "¤1.00"
    end

    specify "#format(:symbol => some non-Boolean value that evaluates to true) returs symbol based on the given currency code" do
      Money.new(100, "GBP").format(:symbol => true).should == "£1.00"
      Money.new(100, "EUR").format(:symbol => true).should == "€1.00"
      Money.new(100, "SEK").format(:symbol => true).should == "kr1.00"
    end

    specify "#format with :symbol == "", nil or false returns the amount without a symbol" do
      money = Money.new(100, "GBP")
      money.format(:symbol => "").should == "1.00"
      money.format(:symbol => nil).should == "1.00"
      money.format(:symbol => false).should == "1.00"
    end

    specify "#format without :symbol assumes that :symbol is set to true" do
      money = Money.new(100)
      money.format.should == "$1.00"

      money = Money.new(100, "GBP")
      money.format.should == "£1.00"

      money = Money.new(100, "EUR")
      money.format.should == "€1.00"
    end

    specify "#format(:separator => a separator string) works as documented" do
      Money.us_dollar(100).format(:separator => ",").should == "$1,00"
    end

    specify "#format will default separator to '.' if currency isn't recognized" do
      Money.new(100, "ZWD").format.should == "$1.00"
    end

    specify "#format(:delimiter => a delimiter string) works as documented" do
      Money.us_dollar(100000).format(:delimiter => ".").should == "$1.000.00"
      Money.us_dollar(200000).format(:delimiter => "").should  == "$2000.00"
    end

    specify "#format(:delimiter => false or nil) works as documented" do
      Money.us_dollar(100000).format(:delimiter => false).should == "$1000.00"
      Money.us_dollar(200000).format(:delimiter => nil).should   == "$2000.00"
    end

    specify "#format will default delimiter to ',' if currency isn't recognized" do
      Money.new(100000, "ZWD").format.should == "$1,000.00"
    end

    specify "#format(:html => true) works as documented" do
      string = Money.ca_dollar(570).format(:html => true, :with_currency => true)
      string.should == "$5.70 <span class=\"currency\">CAD</span>"
    end

    it "should insert commas into the result if the amount is sufficiently large" do
      Money.us_dollar(1_000_000_000_12).format.should == "$1,000,000,000.12"
      Money.us_dollar(1_000_000_000_12).format(:no_cents => true).should == "$1,000,000,000"
    end
    
    it "should put the currency after the value when appropriate" do
      Money.new(1000, "NOK").format.should == "10.00 kr"
    end
  end


  describe "Money.empty" do
    it "Money.empty creates a new Money object of 0 cents" do
      Money.empty.should == Money.new(0)
    end
  end

  describe "Money.ca_dollar" do
    it "creates a new Money object of the given value in CAD" do
      Money.ca_dollar(50).should == Money.new(50, "CAD")
    end
  end

  describe "Money.us_dollar" do
    it "creates a new Money object of the given value in USD" do
      Money.us_dollar(50).should == Money.new(50, "USD")
    end
  end

  describe "Money.euro" do
    it "creates a new Money object of the given value in EUR" do
      Money.euro(50).should == Money.new(50, "EUR")
    end
  end


  describe "Money.new_with_dollars" do
    it "converts given amount to cents" do
      Money.new_with_dollars(1).should == Money.new(100)
      Money.new_with_dollars(1, "USD").should == Money.new(100, "USD")
      Money.new_with_dollars(1, "EUR").should == Money.new(100, "EUR")
    end

    it "should respect :subunit_to_unit currency property" do
      Money.new_with_dollars(1, "USD").should == Money.new(1_00,  "USD")
      Money.new_with_dollars(1, "TND").should == Money.new(1_000, "TND")
      Money.new_with_dollars(1, "CLP").should == Money.new(1,     "CLP")
    end

    it "should not loose precision" do
      Money.new_with_dollars(1234).cents.should == 1234_00
      Money.new_with_dollars(100.37).cents.should == 100_37
      Money.new_with_dollars(BigDecimal.new('1234')).cents.should == 1234_00
    end

    it "accepts a currency options" do
      m = Money.new_with_dollars(1)
      m.currency.should == Money.default_currency

      m = Money.new_with_dollars(1, Money::Currency.wrap("EUR"))
      m.currency.should == Money::Currency.wrap("EUR")

      m = Money.new_with_dollars(1, "EUR")
      m.currency.should == Money::Currency.wrap("EUR")
    end

    it "accepts a bank options" do
      m = Money.new_with_dollars(1)
      m.bank.should == Money.default_bank

      m = Money.new_with_dollars(1, "EUR", bank = Object.new)
      m.bank.should == bank
    end

    it "is associated to the singleton instance of Bank::VariableExchange by default" do
      Money.new_with_dollars(0).bank.should be_equal(Money::Bank::VariableExchange.instance)
    end
  end

  describe "split" do
    specify "#split needs at least one party" do
      lambda {Money.us_dollar(1).split(0)}.should raise_error(ArgumentError)
      lambda {Money.us_dollar(1).split(-1)}.should raise_error(ArgumentError)
    end


    specify "#gives 1 cent to both people if we start with 2" do
      Money.us_dollar(2).split(2).should == [Money.us_dollar(1), Money.us_dollar(1)]
    end

    specify "#split may distribute no money to some parties if there isnt enough to go around" do
      Money.us_dollar(2).split(3).should == [Money.us_dollar(1), Money.us_dollar(1), Money.us_dollar(0)]
    end

    specify "#split does not lose pennies" do
      Money.us_dollar(5).split(2).should == [Money.us_dollar(3), Money.us_dollar(2)]
    end

    specify "#split a dollar" do
      moneys = Money.us_dollar(100).split(3)
      moneys[0].cents.should == 34
      moneys[1].cents.should == 33
      moneys[2].cents.should == 33
    end
  end

  describe "allocation" do
    specify "#allocate takes no action when one gets all" do
      Money.us_dollar(005).allocate([1.0]).should == [Money.us_dollar(5)]
    end

    specify "#allocate keeps currencies intact" do
      Money.ca_dollar(005).allocate([1]).should == [Money.ca_dollar(5)]
    end

    specify "#allocate does not loose pennies" do
      moneys = Money.us_dollar(5).allocate([0.3,0.7])
      moneys[0].should == Money.us_dollar(2)
      moneys[1].should == Money.us_dollar(3)
    end

    specify "#allocate does not loose pennies" do
      moneys = Money.us_dollar(100).allocate([0.333,0.333, 0.333])
      moneys[0].cents.should == 34
      moneys[1].cents.should == 33
      moneys[2].cents.should == 33
    end

    specify "#allocate requires total to be less then 1" do
      lambda { Money.us_dollar(0.05).allocate([0.5,0.6]) }.should raise_error(ArgumentError)
    end
  end

  describe "Money.add_rate" do
    it "saves rate into current bank" do
      Money.add_rate("EUR", "USD", 10)
      Money.new(10_00, "EUR").exchange_to("USD").should == Money.new(100_00, "USD")
    end
  end

end

