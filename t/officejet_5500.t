# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 28;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/officejet_5500';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'jpeg-compression-factor' => {
                                         'tip' => 'Sets the scanner JPEG compression factor.  Larger numbers mean better compression, and smaller numbers mean better image quality.',
                                         'default' => '10',
                                         'values' => '0..100'
                                       },
          'source' => {
                        'tip' => 'Selects the desired scan source for models with both flatbed and automatic document feeder (ADF) capabilities.  The "Auto" setting means that the ADF will be used if it\'s loaded, and the flatbed (if present) will be used otherwise.',
                        'default' => 'Auto',
                        'values' => 'Auto|Flatbed|ADF'
                      },
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Color',
                      'values' => 'Lineart|Grayscale|Color'
                    },
          'length-measurement' => {
                                    'tip' => 'Selects how the scanned image length is measured and reported, which is impossible to know in advance for scrollfed scans.',
                                    'default' => 'Padded',
                                    'values' => 'Unknown|Approximate|Padded'
                                  },
          'contrast' => {
                          'tip' => 'Controls the contrast of the acquired image.',
                          'default' => 'inactive',
                          'values' => '0..100'
                        },
          'duplex' => {
                        'tip' => 'Enables scanning on both sides of the page for models with duplex-capable document feeders.  For pages printed in "book"-style duplex mode, one side will be scanned upside-down.  This feature is experimental.',
                        'default' => 'inactive',
                        'values' => 'yes|no'
                      },
          'compression' => {
                             'tip' => 'Selects the scanner compression method for faster scans, possibly at the expense of image quality.',
                             'default' => 'JPEG',
                             'values' => 'None|JPEG'
                           },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '75',
                            'values' => '75..600dpi'
                          },
          'batch-scan' => {
                            'tip' => 'Guarantees that a "no documents" condition will be returned after the last scanned page, to prevent endless flatbed scans after a batch scan. For some models, option changes in the middle of a batch scan don\'t take effect until after the last page.',
                            'default' => 'no',
                            'values' => 'yes|no'
                          }
        );
foreach my $option (keys %this) {
 foreach (qw(tip default values)) {
  is ($this{$option}{$_}, $that{$option}{$_}, "$option, $_");
 }
}
eq_hash(\%this, \%that);
