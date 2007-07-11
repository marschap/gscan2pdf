# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 13;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/canoscan_FB_630P';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Gray',
                      'values' => 'Gray|Color'
                    },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '75',
                            'values' => '75|150|300|600dpi'
                          },
          'quality-cal' => {
                             'tip' => 'Do a quality white-calibration',
                             'default' => '',
                             'values' => ''
                           },
          'depth' => {
                       'tip' => 'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
                       'default' => '8',
                       'values' => '8|12'
                     }
        );
foreach my $option (keys %this) {
 foreach (qw(tip default values)) {
  is ($this{$option}{$_}, $that{$option}{$_}, "$option, $_");
 }
}
eq_hash(\%this, \%that);
