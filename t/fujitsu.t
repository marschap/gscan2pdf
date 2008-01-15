# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/fujitsu';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'source' => {
                        'tip' => 'Selects the scan source (such as a document-feeder).',
                        'default' => 'ADF Front',
                        'values' => ['ADF Front','ADF Back','ADF Duplex']
                      },
          'rif' => {
                     'tip' => 'Reverse image format',
                     'default' => 'no',
                     'values' => ['yes','no']
                   },
          'sleeptimer' => {
                            'tip' => 'Time in minutes until the internal power supply switches to sleep mode',
                            'default' => '0',
                                   'min' => 0,
                            'max' => 60,
                            'step' => 1,
                          },
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Gray',
                      'values' => ['Gray','Color']
                    },
          'pageheight' => {
                            'tip' => 'Must be set properly to eject pages',
                            'default' => '279.364',
                                   'min' => 0,
                            'max' => 863.489,
                            'step' => 0.0211639,
                          },
          'pagewidth' => {
                           'tip' => 'Must be set properly to align scanning window',
                           'default' => '215.872',
                                   'min' => 0,
                            'max' => 224.846,
                            'step' => 0.0211639,
                         },
          'y-resolution' => {
                              'tip' => 'Sets the vertical resolution of the scanned image.',
                              'default' => '600',
                                   'min' => 50,
                            'max' => 600,
                            'step' => 1,
                            },
          'dropoutcolor' => {
                              'tip' => 'One-pass scanners use only one color during gray or binary scanning, useful for colored paper or ink',
                              'default' => 'Default',
                              'values' => ['Default','Red','Green','Blue']
                            },
          'resolution' => {
                            'tip' => 'Sets the horizontal resolution of the scanned image.',
                            'default' => '600',
                                   'min' => 100,
                            'max' => 600,
                            'step' => 1,
                          }
        );
is_deeply(\%this, \%that, 'fujitsu');
