# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
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
                      'values' => ['Gray','Color']
                    },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '75',
                            'values' => ['75','150','300','600'],
                   'unit' => 'dpi',
                          },
          'quality-cal' => {
                             'tip' => 'Do a quality white-calibration',
                             'default' => '',
                           },
          'depth' => {
                       'tip' => 'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
                       'default' => '8',
                       'values' => ['8','12']
                     },
          'l' => {
                   'tip' => 'Top-left x position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 215,
                   'step' => 1869504867,
                   'unit' => 'mm',
                 },
          't' => {
                   'tip' => 'Top-left y position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 296,
                   'step' => 1852795252,
                   'unit' => 'mm',
                 },
          'x' => {
                   'tip' => 'Width of scan-area.',
                   'default' => 100,
                   'min' => 3,
                   'max' => 216,
                   'step' => 16,
                   'unit' => 'mm',
                 },
          'y' => {
                   'tip' => 'Height of scan-area.',
                   'default' => 100,
                   'min' => 1,
                   'max' => 297,
                   'unit' => 'mm',
                 }
        );
is_deeply(\%this, \%that, 'canoscan_FB_630P');
