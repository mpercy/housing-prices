#!/usr/bin/perl
################################################################################
# Calculates rent-to-price ratio per Metro on a sqft basis, given Zillow data.
# Input: CSV formatted Zillow data.
# Output: TSV formatted output.
# See https://www.zillow.com/research/data/
################################################################################
use strict;
use warnings;

use Text::CSV;

use constant REGION_COL => 'RegionName';

if (scalar @ARGV != 3) {
  print STDERR "Usage: $0 price_by_metro rent_by_metro month\n";
  print STDERR "Example: $0 Metro_MedianValuePerSqft_AllHomes.csv Metro_MedianRentalPricePerSqft_1Bedroom.csv 2017-06\n";
  exit 1;
}

my $price_by_metro = $ARGV[0];
my $rent_by_metro = $ARGV[1];
my $month = $ARGV[2];

# Returns a closure that, when called, returns a hashref representing one line
# of the CSV file keyed by column name.
sub get_parser($) {
  my $filename = shift or die 'missing filename';
  my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
      or die "Cannot use CSV: " . Text::CSV->error_diag();
  open my $fh, "<:encoding(utf8)", $filename or die "$filename: $!";

  my @col_names = @{ $csv->getline($fh) };
  $csv->column_names(@col_names);

  return sub {
    return $csv->getline_hr($fh);
  };
}

# Exhausts the given parser closure and returns a plain hash keyed by metro
# with a value equal to the cell value of the specified month.
sub filter_by_month($$) {
  my $parser = shift or die 'no parser';
  my $month = shift or die 'no month';
  my %vals;
  while (defined(my $row = $parser->())) {
    next unless exists $row->{$month};
    $vals{$row->{REGION_COL()}} = $row->{$month};
  }
  return %vals;
}

sub print_row($) {
  my $row = shift or die 'missing row';
  printf("%s\t%s\t%s\t%s\n", @$row);
}

my $price_parser = get_parser($price_by_metro);
my %prices = filter_by_month($price_parser, $month);

my $rent_parser = get_parser($rent_by_metro);
my %rents = filter_by_month($rent_parser, $month);

# Perform an inner join on the two files by metro.
my @table;
foreach my $metro (keys %prices) {
  next unless exists $rents{$metro};
  push @table, [ $metro, $rents{$metro}, $prices{$metro}, $rents{$metro} / $prices{$metro} ];
}

# Sort by rent/price descending.
@table = sort { $b->[3] <=> $a->[3] } @table;

# Print tsv.
print_row([qw(Metro Rent/sqft Price/sqft rent-to-price)]);
foreach my $row (@table) {
  print_row($row);
}

exit 0;
