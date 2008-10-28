# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/snapscan';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'source' => {
                        'tip' => 'Selects the scan source (such as a document-feeder).',
                        'default' => 'inactive',
                        'values' => ['auto','Flatbed']
                      },
          'gamma-table' => {
                             'tip' => 'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
                             'default' => 'inactive',
                                   'min' => 0,
                            'max' => 65535,
                            'step' => 1,
                           },
          'halftoning' => {
                            'tip' => 'Selects whether the acquired image should be halftoned (dithered).',
                            'default' => 'inactive',
                            'values' => ['yes','no']
                          },
          'threshold' => {
                           'tip' => 'Select minimum-brightness to get a white point',
                           'default' => 'inactive',
                                   'min' => 0,
                            'max' => 100,
                            'step' => 1,
                        'unit' => '%',
                         },
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Color',
                      'values' => ['auto','Color','Halftone','Gray','Lineart']
                    },
          'analog-gamma-bind' => {
                                   'tip' => 'In RGB-mode use same values for each color',
                                   'default' => 'no',
                                   'values' => ['yes','no']
                                 },
          'red-gamma-table' => {
                                 'tip' => 'Gamma-correction table for the red band.',
                                 'default' => 'inactive',
                                 'min' => 0,
                            'max' => 65535,
                            'step' => 1,
                               },
          'green-gamma-table' => {
                                   'tip' => 'Gamma-correction table for the green band.',
                                   'default' => 'inactive',
                                   'min' => 0,
                            'max' => 65535,
                            'step' => 1,
                                 },
          'custom-gamma' => {
                              'tip' => 'Determines whether a builtin or a custom gamma-table should be used.',
                              'default' => 'no',
                              'values' => ['yes','no']
                            },
          'rgb-lpr' => {
                         'tip' => 'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
                         'default' => '4',
                                   'min' => 1,
                            'max' => 50,
                            'step' => 1,
                       },
          'analog-gamma' => {
                              'tip' => 'Analog gamma-correction',
                              'default' => 'inactive',
                                   'min' => 0,
                            'max' => 4,
                            },
          'blue-gamma-table' => {
                                  'tip' => 'Gamma-correction table for the blue band.',
                                  'default' => 'inactive',
                                  'min' => 0,
                            'max' => 65535,
                            'step' => 1,
                                },
          'gs-lpr' => {
                        'tip' => 'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
                        'default' => 'inactive',
                        'min' => 1,
                            'max' => 50,
                            'step' => 1,
                      },
          'predef-window' => {
                               'tip' => 'Provides standard scanning areas for photographs, printed pages and the like.',
                               'default' => 'None',
                               'values' => ['None','6x4 (inch)','8x10 (inch)','8.5x11 (inch)']
                             },
          'analog-gamma-b' => {
                                'tip' => 'Analog gamma-correction for blue',
                                'default' => '1.79999',
                                'min' => 0,
                            'max' => 4,
                              },
          'contrast' => {
                          'tip' => 'Controls the contrast of the acquired image.',
                          'default' => '0',
                                  'min' => -100,
                            'max' => 400,
                            'step' => 1,
                        'unit' => '%',
                        },
          'analog-gamma-g' => {
                                'tip' => 'Analog gamma-correction for green',
                                'default' => '1.79999',
                                'min' => 0,
                            'max' => 4,
                              },
          'quality-cal' => {
                             'tip' => 'Do a quality white-calibration',
                             'default' => 'yes',
                             'values' => ['yes','no']
                           },
          'depth' => {
                       'tip' => 'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
                       'default' => 'inactive',
                       'values' => ['8'],
                        'unit' => 'bit',
                     },
          'analog-gamma-r' => {
                                'tip' => 'Analog gamma-correction for red',
                                'default' => '1.79999',
                                'min' => 0,
                            'max' => 4,
                              },
          'brightness' => {
                            'tip' => 'Controls the brightness of the acquired image.',
                            'default' => '0',
                                  'min' => -400,
                            'max' => 400,
                            'step' => 1,
                        'unit' => '%',
                          },
          'preview-mode' => {
                              'tip' => 'Select the mode for previews. Greyscale previews usually give the best combination of speed and detail.',
                              'default' => 'Auto',
                              'values' => ['auto','Auto','Color','Halftone','Gray','Lineart']
                            },
          'high-quality' => {
                              'tip' => 'Highest quality but lower speed',
                              'default' => 'no',
                              'values' => ['auto','yes','no']
                            },
          'preview' => {
                         'tip' => 'Request a preview-quality scan.',
                         'default' => 'no',
                         'values' => ['auto','yes','no']
                       },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '300',
                            'values' => ['auto','50','75','100','150','200','300','450','600'],
                        'unit' => 'dpi',
                          },
          'negative' => {
                          'tip' => 'Swap black and white',
                          'default' => 'inactive',
                          'values' => ['auto','yes','no']
                        },
          'halftone-pattern' => {
                                  'tip' => 'Defines the halftoning (dithering) pattern for scanning halftoned images.',
                                  'default' => 'inactive',
                                  'values' => ['DispersedDot8x8','DispersedDot16x16']
                                },
          'l' => {
                   'tip' => 'Top-left x position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 216,
                        'unit' => 'mm',
                 },
          't' => {
                   'tip' => 'Top-left y position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 297,
                        'unit' => 'mm',
                 },
          'x' => {
                   'tip' => 'Width of scan-area.',
                   'default' => 216,
                   'min' => 0,
                   'max' => 216,
                        'unit' => 'mm',
                 },
          'y' => {
                   'tip' => 'Height of scan-area.',
                   'default' => 297,
                   'min' => 0,
                   'max' => 297,
                        'unit' => 'mm',
                 }
        );
is_deeply(\%this, \%that, 'snapscan');
