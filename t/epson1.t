# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 112;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/epson1';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Binary',
                      'values' => 'Binary|Gray|Color'
                    },
          'cct-5' => {
                       'tip' => 'Controls red level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'eject' => {
                       'tip' => 'Eject the sheet in the ADF',
                       'default' => 'inactive',
                       'values' => ''
                     },
          'cct-9' => {
                       'tip' => 'Controls blue level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'cct-7' => {
                       'tip' => 'Adds to green based on blue level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'cct-2' => {
                       'tip' => 'Adds to red based on green level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'color-correction' => {
                                  'tip' => 'Sets the color correction table for the selected output device.',
                                  'default' => 'CRT monitors',
                                  'values' => 'No Correction|User defined|Impact-dot printers|Thermal printers|Ink-jet printers|CRT monitors'
                                },
          'adf_mode' => {
                          'tip' => 'Selects the ADF mode (simplex/duplex)',
                          'default' => 'inactive',
                          'values' => 'Simplex|Duplex'
                        },
          'cct-1' => {
                       'tip' => 'Controls green level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'depth' => {
                       'tip' => 'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
                       'default' => 'inactive',
                       'values' => '8|16'
                     },
          'brightness' => {
                            'tip' => 'Selects the brightness.',
                            'default' => '0',
                            'values' => '-4..3'
                          },
          'dropout' => {
                         'tip' => 'Selects the dropout.',
                         'default' => 'None',
                         'values' => 'None|Red|Green|Blue'
                       },
          'preview-speed' => {
                               'tip' => '',
                               'default' => 'no',
                               'values' => 'yes|no'
                             },
          'preview' => {
                         'tip' => 'Request a preview-quality scan.',
                         'default' => 'no',
                         'values' => 'yes|no'
                       },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '50',
                            'values' => '50|60|72|75|80|90|100|120|133|144|150|160|175|180|200|216|240|266|300|320|350|360|400|480|600|720|800|900|1200|1600|1800|2400|3200dpi'
                          },
          'wait-for-button' => {
                                 'tip' => 'After sending the scan command, wait until the button on the scanner is pressed to actually start the scan process.',
                                 'default' => 'no',
                                 'values' => 'yes|no'
                               },
          'source' => {
                        'tip' => 'Selects the scan source (such as a document-feeder).',
                        'default' => 'Flatbed',
                        'values' => 'Flatbed|Transparency Unit'
                      },
          'cct-8' => {
                       'tip' => 'Adds to red based on blue level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'threshold' => {
                           'tip' => 'Select minimum-brightness to get a white point',
                           'default' => 'inactive',
                           'values' => '0..255'
                         },
          'mirror' => {
                        'tip' => 'Mirror the image.',
                        'default' => 'no',
                        'values' => 'yes|no'
                      },
          'red-gamma-table' => {
                                 'tip' => 'Gamma-correction table for the red band.',
                                 'default' => 'inactive',
                                 'values' => '0..255,...'
                               },
          'green-gamma-table' => {
                                   'tip' => 'Gamma-correction table for the green band.',
                                   'default' => 'inactive',
                                   'values' => '0..255,...'
                                 },
          'auto-area-segmentation' => {
                                        'tip' => '',
                                        'default' => 'yes',
                                        'values' => 'yes|no'
                                      },
          'short-resolution' => {
                                        'tip' => 'Display short resolution list',
                                        'default' => 'no',
                                        'values' => 'yes|no'
                                      },
          'cct-4' => {
                       'tip' => 'Adds to green based on red level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'speed' => {
                       'tip' => 'Determines the speed at which the scan proceeds.',
                       'default' => 'no',
                       'values' => 'yes|no'
                     },
          'film-type' => {
                           'tip' => '',
                           'default' => 'inactive',
                           'values' => 'Positive Film|Negative Film'
                         },
          'focus-position' => {
                           'tip' => 'Sets the focus position to either the glass or 2.5mm above the glass',
                           'default' => 'Focus on glass',
                           'values' => 'Focus on glass|Focus 2.5mm above glass'
                         },
          'blue-gamma-table' => {
                                  'tip' => 'Gamma-correction table for the blue band.',
                                  'default' => 'inactive',
                                  'values' => '0..255,...'
                                },
          'bay' => {
                     'tip' => 'Select bay to scan',
                     'default' => 'inactive',
                     'values' => ' 1 | 2 | 3 | 4 | 5 | 6 '
                   },
          'zoom' => {
                      'tip' => 'Defines the zoom factor the scanner will use',
                      'default' => 'inactive',
                      'values' => '50..200'
                    },
          'auto-eject' => {
                            'tip' => 'Eject document after scanning',
                            'default' => 'inactive',
                            'values' => 'yes|no'
                          },
          'sharpness' => {
                           'tip' => '',
                           'default' => '0',
                           'values' => '-2..2'
                         },
          'gamma-correction' => {
                           'tip' => 'Selects the gamma correction value from a list of pre-defined devices or the user defined table, which can be downloaded to the scanner',
                           'default' => 'Default',
                           'values' => 'Default|User defined|High density printing|Low density printing|High contrast printing'
                         },
          'quick-format' => {
                              'tip' => '',
                              'default' => 'Max',
                              'values' => 'CD|A5 portrait|A5 landscape|Letter|A4|Max'
                            },
          'cct-6' => {
                       'tip' => 'Adds to blue based on red level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     },
          'cct-3' => {
                       'tip' => 'Adds to blue based on green level',
                       'default' => 'inactive',
                       'values' => '-127..127'
                     }
        );
foreach my $option (keys %this) {
 foreach (qw(tip default values)) {
  is ($this{$option}{$_}, $that{$option}{$_}, "$option, $_");
 }
}
eq_hash(\%this, \%that);
