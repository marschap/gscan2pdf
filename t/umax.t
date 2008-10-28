# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/umax';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'holder-focus-position-0mm' => {
                                           'tip' => 'Use 0mm holder focus position instead of 0.6mm',
                                           'default' => 'inactive',
                                           'values' => ['yes','no']
                                         },
          'cal-lamp-density' => {
                                  'tip' => 'Define lamp density for calibration',
                                  'default' => 'inactive',
                                  'min' => 0,
                                  'max' => 100,
                        'unit' => '%',
                                },
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Color',
                      'values' => ['Lineart','Gray','Color']
                    },
          'shadow-r' => {
                          'tip' => 'Selects what red radiance level should be considered "black".',
                          'default' => 'inactive',
                          'min' => 0,
                          'max' => 100,
                        'unit' => '%',
                        },
          'scan-exposure-time-g' => {
                                      'tip' => 'Define exposure-time for green scan',
                                      'default' => 'inactive',
                                      'min' => 0,
                                      'max' => 0,
                        'unit' => 'us',
                                    },
          'scan-exposure-time-r' => {
                                      'tip' => 'Define exposure-time for red scan',
                                      'default' => 'inactive',
                                      'min' => 0,
                                      'max' => 0,
                        'unit' => 'us',
                                    },
          'lamp-on' => {
                         'tip' => 'Turn on scanner lamp',
                         'default' => 'inactive',
                       },
          'lens-calibration-in-doc-position' => {
                                                  'tip' => 'Calibrate lens focus in document position',
                                                  'default' => 'inactive',
                                                  'values' => ['yes','no']
                                                },
          'rgb-bind' => {
                          'tip' => 'In RGB-mode use same values for each color',
                          'default' => 'no',
                          'values' => ['yes','no']
                        },
          'analog-gamma' => {
                              'tip' => 'Analog gamma-correction',
                              'default' => 'inactive',
                                   'min' => 1,
                            'max' => 2,
                            'step' => 0.00999451,
                            },
          'manual-pre-focus' => {
                                  'tip' => '',
                                  'default' => 'inactive',
                                  'values' => ['yes','no']
                                },
          'scan-exposure-time-b' => {
                                      'tip' => 'Define exposure-time for blue scan',
                                      'default' => 'inactive',
                                      'min' => 0,
                                      'max' => 0,
                        'unit' => 'us',
                                    },
          'analog-gamma-b' => {
                                'tip' => 'Analog gamma-correction for blue',
                                'default' => 'inactive',
                                'min' => 1,
                            'max' => 2,
                            'step' => 0.00999451,
                              },
          'shadow' => {
                        'tip' => 'Selects what radiance level should be considered "black".',
                        'default' => 'inactive',
                        'min' => 0,
                        'max' => 100,
                        'unit' => '%',
                      },
          'halftone-size' => {
                               'tip' => 'Sets the size of the halftoning (dithering) pattern used when scanning halftoned images.',
                               'default' => 'inactive',
                               'values' => ['2','4','6','8','12'],
                        'unit' => 'pel',
                             },
          'quality-cal' => {
                             'tip' => 'Do a quality white-calibration',
                             'default' => 'yes',
                             'values' => ['yes','no']
                           },
          'cal-exposure-time-r' => {
                                     'tip' => 'Define exposure-time for red calibration',
                                     'default' => 'inactive',
                                     'min' => 0,
                                      'max' => 0,
                        'unit' => 'us',
                                   },
          'depth' => {
                       'tip' => 'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
                       'default' => '8',
                       'values' => ['8'],
                        'unit' => 'bit',
                     },
          'warmup' => {
                        'tip' => 'Warmup lamp before scanning',
                        'default' => 'inactive',
                        'values' => ['yes','no']
                      },
          'fix-focus-position' => {
                                    'tip' => '',
                                    'default' => 'inactive',
                                    'values' => ['yes','no']
                                  },
          'brightness' => {
                            'tip' => 'Controls the brightness of the acquired image.',
                            'default' => 'inactive',
                                   'min' => -100,
                            'max' => 100,
                            'step' => 1,
                        'unit' => '%',
                          },
          'highlight-g' => {
                             'tip' => 'Selects what green radiance level should be considered "full green".',
                             'default' => '100',
                             'min' => 0,
                             'max' => 100,
                        'unit' => '%',
                           },
          'analog-gamma-r' => {
                                'tip' => 'Analog gamma-correction for red',
                                'default' => 'inactive',
                                'min' => 1,
                            'max' => 2,
                            'step' => 0.00999451,
                              },
          'y-resolution' => {
                              'tip' => 'Sets the vertical resolution of the scanned image.',
                              'default' => 'inactive',
                                'min' => 5,
                            'max' => 600,
                            'step' => 5,
                        'unit' => 'dpi',
                            },
          'preview' => {
                         'tip' => 'Request a preview-quality scan.',
                         'default' => 'no',
                         'values' => ['yes','no']
                       },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '100',
                                'min' => 5,
                            'max' => 300,
                            'step' => 5,
                        'unit' => 'dpi',
                          },
          'negative' => {
                          'tip' => 'Swap black and white',
                          'default' => 'inactive',
                          'values' => ['yes','no']
                        },
          'batch-scan-end' => {
                                'tip' => 'set for last scan of batch',
                                'default' => 'inactive',
                                'values' => ['yes','no']
                              },
          'source' => {
                        'tip' => 'Selects the scan source (such as a document-feeder).',
                        'default' => 'Flatbed',
                        'values' => ['Flatbed']
                      },
          'scan-exposure-time' => {
                                    'tip' => 'Define exposure-time for scan',
                                    'default' => 'inactive',
                                    'min' => 0,
                                      'max' => 0,
                        'unit' => 'us',
                                  },
          'threshold' => {
                           'tip' => 'Select minimum-brightness to get a white point',
                           'default' => 'inactive',
                           'min' => 0,
                           'max' => 100,
                        'unit' => '%',
                         },
          'highlight-r' => {
                             'tip' => 'Selects what red radiance level should be considered "full red".',
                             'default' => '100',
                             'min' => 0,
                             'max' => 100,
                        'unit' => '%',
                           },
          'batch-scan-loop' => {
                                 'tip' => 'set for middle scans of batch',
                                 'default' => 'inactive',
                                 'values' => ['yes','no']
                               },
          'custom-gamma' => {
                              'tip' => 'Determines whether a builtin or a custom gamma-table should be used.',
                              'default' => 'yes',
                              'values' => ['yes','no']
                            },
          'shadow-g' => {
                          'tip' => 'Selects what green radiance level should be considered "black".',
                          'default' => 'inactive',
                          'min' => 0,
                          'max' => 100,
                        'unit' => '%',
                        },
          'batch-scan-start' => {
                                  'tip' => 'set for first scan of batch',
                                  'default' => 'inactive',
                                  'values' => ['yes','no']
                                },
          'batch-scan-next-tl-y' => {
                                      'tip' => 'Set top left Y position for next scan',
                                      'default' => 'inactive',
                          'min' => 0,
                          'max' => 297.18,
                        'unit' => 'mm',
                                    },
          'resolution-bind' => {
                                 'tip' => 'Use same values for X and Y resolution',
                                 'default' => 'yes',
                                 'values' => ['yes','no']
                               },
          'cal-exposure-time-b' => {
                                     'tip' => 'Define exposure-time for blue calibration',
                                     'default' => 'inactive',
                                     'min' => 0,
                                     'max' => 0,
                        'unit' => 'us',
                                   },
          'highlight-b' => {
                             'tip' => 'Selects what blue radiance level should be considered "full blue".',
                             'default' => '100',
                             'min' => 0,
                             'max' => 100,
                        'unit' => '%',
                           },
          'disable-pre-focus' => {
                                   'tip' => 'Do not calibrate focus',
                                   'default' => 'inactive',
                                   'values' => ['yes','no']
                                 },
          'highlight' => {
                           'tip' => 'Selects what radiance level should be considered "white".',
                           'default' => 'inactive',
                           'min' => 0,
                           'max' => 100,
                        'unit' => '%',
                         },
          'double-res' => {
                            'tip' => 'Use lens that doubles optical resolution',
                            'default' => 'inactive',
                            'values' => ['yes','no']
                          },
          'select-lamp-density' => {
                                     'tip' => 'Enable selection of lamp density',
                                     'default' => 'inactive',
                                     'values' => ['yes','no']
                                   },
          'shadow-b' => {
                          'tip' => 'Selects what blue radiance level should be considered "black".',
                          'default' => 'inactive',
                          'min' => 0,
                          'max' => 100,
                        'unit' => '%',
                        },
          'lamp-off' => {
                          'tip' => 'Turn off scanner lamp',
                          'default' => 'inactive',
                        },
          'cal-exposure-time-g' => {
                                     'tip' => 'Define exposure-time for green calibration',
                                     'default' => 'inactive',
                                     'min' => 0,
                                     'max' => 0,
                        'unit' => 'us',
                                   },
          'scan-lamp-density' => {
                                   'tip' => 'Define lamp density for scan',
                                   'default' => 'inactive',
                                   'min' => 0,
                                   'max' => 100,
                        'unit' => '%',
                                 },
          'analog-gamma-g' => {
                                'tip' => 'Analog gamma-correction for green',
                                'default' => 'inactive',
                                'min' => 1,
                                'max' => 2,
                                'step' => 0.00999451,
                              },
          'contrast' => {
                          'tip' => 'Controls the contrast of the acquired image.',
                          'default' => 'inactive',
                          'min' => -100,
                            'max' => 100,
                            'step' => 1,
                        'unit' => '%',
                        },
          'cal-exposure-time' => {
                                   'tip' => 'Define exposure-time for calibration',
                                   'default' => 'inactive',
                                   'min' => 0,
                                      'max' => 0,
                        'unit' => 'us',
                                 },
          'lamp-off-at-exit' => {
                                  'tip' => 'Turn off lamp when program exits',
                                  'default' => 'inactive',
                                  'values' => ['yes','no']
                                },
          'select-calibration-exposure-time' => {
                                                  'tip' => 'Allow different settings for calibration and scan exposure times',
                                                  'default' => 'inactive',
                                                  'values' => ['yes','no']
                                                },
          'halftone-pattern' => {
                                  'tip' => 'Defines the halftoning (dithering) pattern for scanning halftoned images.',
                                  'default' => 'inactive',
                                  'min' => 0,
                            'max' => 255,
                                },
          'select-exposure-time' => {
                                      'tip' => 'Enable selection of exposure-time',
                                      'default' => 'inactive',
                                      'values' => ['yes','no']
                                    },
          'l' => {
                   'tip' => 'Top-left x position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 215.9,
                        'unit' => 'mm',
                 },
          't' => {
                   'tip' => 'Top-left y position of scan area.',
                   'default' => 0,
                   'min' => 0,
                   'max' => 297.18,
                        'unit' => 'mm',
                 },
          'x' => {
                   'tip' => 'Width of scan-area.',
                   'default' => 215.9,
                   'min' => 0,
                   'max' => 215.9,
                        'unit' => 'mm',
                 },
          'y' => {
                   'tip' => 'Height of scan-area.',
                   'default' => 297.18,
                   'min' => 0,
                   'max' => 297.18,
                        'unit' => 'mm',
                 }
        );
is_deeply(\%this, \%that, 'umax');
