# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/canonLiDE25';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'source' => {
                        'tip' => 'Selects the scan source (such as a document-feeder).',
                        'default' => 'inactive',
                        'values' => ['Normal','Transparency','Negative']
                      },
          'gamma-table' => {
                             'tip' => 'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
                             'default' => 'inactive',
                            'min' => 0,
                            'max' => 255,
                           },
          'lamp-switch' => {
                             'tip' => 'Manually switching the lamp(s).',
                             'default' => 'no',
                             'values' => ['yes','no']
                           },
          'blue-offset' => {
                             'tip' => 'Blue offset value of the AFE',
                             'default' => '-1',
                            'min' => -1,
                            'max' => 63,
                            'step' => 1,
                           },
          'redlamp-off' => {
                             'tip' => 'Defines red lamp off parameter',
                             'default' => '-1',
                            'min' => -1,
                            'max' => 16363,
                            'step' => 1,
                           },
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Color',
                      'values' => ['Lineart','Gray','Color']
                    },
          'red-gamma-table' => {
                                 'tip' => 'Gamma-correction table for the red band.',
                                 'default' => 'inactive',
                            'min' => 0,
                            'max' => 255,
                               },
          'green-gamma-table' => {
                                   'tip' => 'Gamma-correction table for the green band.',
                                   'default' => 'inactive',
                            'min' => 0,
                            'max' => 255,
                                 },
          'custom-gamma' => {
                              'tip' => 'Determines whether a builtin or a custom gamma-table should be used.',
                              'default' => 'no',
                              'values' => ['yes','no']
                            },
          'calibration-cache' => {
                                   'tip' => 'Enables or disables calibration data cache.',
                                   'default' => 'no',
                                   'values' => ['yes','no']
                                 },
          'green-gain' => {
                            'tip' => 'Green gain value of the AFE',
                            'default' => '-1',
                            'min' => -1,
                            'max' => 63,
                            'step' => 1,
                          },
          'blue-gamma-table' => {
                                  'tip' => 'Gamma-correction table for the blue band.',
                                  'default' => 'inactive',
                            'min' => 0,
                            'max' => 255,
                                },
          'red-gain' => {
                          'tip' => 'Red gain value of the AFE',
                          'default' => '-1',
                            'min' => -1,
                            'max' => 63,
                            'step' => 1,
                        },
          'bluelamp-off' => {
                              'tip' => 'Defines blue lamp off parameter',
                              'default' => '-1',
                            'min' => -1,
                            'max' => 16363,
                            'step' => 1,
                            },
          'contrast' => {
                          'tip' => 'Controls the contrast of the acquired image.',
                          'default' => '0',
                            'min' => -100,
                            'max' => 100,
                            'step' => 1,
                        },
          'greenlamp-off' => {
                               'tip' => 'Defines green lamp off parameter',
                               'default' => '-1',
                            'min' => -1,
                            'max' => 16363,
                            'step' => 1,
                             },
          'speedup-switch' => {
                                'tip' => 'Enables or disables speeding up sensor movement.',
                                'default' => 'inactive',
                              'values' => ['yes','no'],
                              },
          'warmup-time' => {
                             'tip' => 'Warmup-time in seconds.',
                             'default' => 'inactive',
                            'min' => -1,
                            'max' => 999,
                            'step' => 1,
                           },
          'depth' => {
                       'tip' => 'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
                       'default' => '8',
                       'values' => ['8','16']
                     },
          'red-offset' => {
                            'tip' => 'Red offset value of the AFE',
                            'default' => '-1',
                            'min' => -1,
                            'max' => 63,
                            'step' => 1,
                          },
          'lamp-off-at-exit' => {
                                  'tip' => 'Turn off lamp when program exits',
                                  'default' => 'yes',
                                  'values' => ['yes','no'],
                                },
          'calibrate' => {
                           'tip' => 'Performs calibration',
                           'default' => 'inactive',
                         },
          'blue-gain' => {
                           'tip' => 'Blue gain value of the AFE',
                           'default' => '-1',
                           'min' => -1,
                            'max' => 63,
                            'step' => 1,
                         },
          'green-offset' => {
                              'tip' => 'Green offset value of the AFE',
                              'default' => '-1',
                              'min' => -1,
                            'max' => 63,
                            'step' => 1,
                            },
          'brightness' => {
                            'tip' => 'Controls the brightness of the acquired image.',
                            'default' => '0',
                            'min' => -100,
                            'max' => 100,
                            'step' => 1,

                          },
          'preview' => {
                         'tip' => 'Request a preview-quality scan.',
                         'default' => 'no',
                         'values' => ['yes','no'],
                       },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '50',
                            'min' => 50,
                            'max' => 2400,
                          },
          'lampoff-time' => {
                              'tip' => 'Lampoff-time in seconds.',
                              'default' => '300',
                              'min' => 0,
                              'max' => 999,
                              'step' => 1,
                            },
          'l' => {
                   'tip' => 'Top-left x position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 215,
                 },
          't' => {
                   'tip' => 'Top-left y position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 297,
                 },
          'x' => {
                   'tip' => 'Width of scan-area.',
                   'default' => 103,
                   'min' => 0,
                   'max' => 215,
                 },
          'y' => {
                   'tip' => 'Height of scan-area.',
                   'default' => 76.21,
                   'min' => 0,
                   'max' => 297,
                 }

        );
is_deeply(\%this, \%that, 'canonLiDE25');
