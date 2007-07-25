# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 166;
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
                                           'values' => 'yes|no'
                                         },
          'cal-lamp-density' => {
                                  'tip' => 'Define lamp density for calibration',
                                  'default' => 'inactive',
                                  'values' => '0..100%'
                                },
          'mode' => {
                      'tip' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
                      'default' => 'Color',
                      'values' => 'Lineart|Gray|Color'
                    },
          'shadow-r' => {
                          'tip' => 'Selects what red radiance level should be considered "black".',
                          'default' => 'inactive',
                          'values' => '0..100%'
                        },
          'scan-exposure-time-g' => {
                                      'tip' => 'Define exposure-time for green scan',
                                      'default' => 'inactive',
                                      'values' => '0..0us'
                                    },
          'scan-exposure-time-r' => {
                                      'tip' => 'Define exposure-time for red scan',
                                      'default' => 'inactive',
                                      'values' => '0..0us'
                                    },
          'lamp-on' => {
                         'tip' => 'Turn on scanner lamp',
                         'default' => 'inactive',
                         'values' => ''
                       },
          'lens-calibration-in-doc-position' => {
                                                  'tip' => 'Calibrate lens focus in document position',
                                                  'default' => 'inactive',
                                                  'values' => 'yes|no'
                                                },
          'rgb-bind' => {
                          'tip' => 'In RGB-mode use same values for each color',
                          'default' => 'no',
                          'values' => 'yes|no'
                        },
          'analog-gamma' => {
                              'tip' => 'Analog gamma-correction',
                              'default' => 'inactive',
                              'values' => '1..2 (in steps of 0.00999451)'
                            },
          'manual-pre-focus' => {
                                  'tip' => '',
                                  'default' => 'inactive',
                                  'values' => 'yes|no'
                                },
          'scan-exposure-time-b' => {
                                      'tip' => 'Define exposure-time for blue scan',
                                      'default' => 'inactive',
                                      'values' => '0..0us'
                                    },
          'analog-gamma-b' => {
                                'tip' => 'Analog gamma-correction for blue',
                                'default' => 'inactive',
                                'values' => '1..2 (in steps of 0.00999451)'
                              },
          'shadow' => {
                        'tip' => 'Selects what radiance level should be considered "black".',
                        'default' => 'inactive',
                        'values' => '0..100%'
                      },
          'halftone-size' => {
                               'tip' => 'Sets the size of the halftoning (dithering) pattern used when scanning halftoned images.',
                               'default' => 'inactive',
                               'values' => '2|4|6|8|12pel'
                             },
          'quality-cal' => {
                             'tip' => 'Do a quality white-calibration',
                             'default' => 'yes',
                             'values' => 'yes|no'
                           },
          'cal-exposure-time-r' => {
                                     'tip' => 'Define exposure-time for red calibration',
                                     'default' => 'inactive',
                                     'values' => '0..0us'
                                   },
          'depth' => {
                       'tip' => 'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
                       'default' => '8',
                       'values' => '8bit'
                     },
          'warmup' => {
                        'tip' => 'Warmup lamp before scanning',
                        'default' => 'inactive',
                        'values' => 'yes|no'
                      },
          'fix-focus-position' => {
                                    'tip' => '',
                                    'default' => 'inactive',
                                    'values' => 'yes|no'
                                  },
          'brightness' => {
                            'tip' => 'Controls the brightness of the acquired image.',
                            'default' => 'inactive',
                            'values' => '-100..100% (in steps of 1)'
                          },
          'highlight-g' => {
                             'tip' => 'Selects what green radiance level should be considered "full green".',
                             'default' => '100',
                             'values' => '0..100%'
                           },
          'analog-gamma-r' => {
                                'tip' => 'Analog gamma-correction for red',
                                'default' => 'inactive',
                                'values' => '1..2 (in steps of 0.00999451)'
                              },
          'y-resolution' => {
                              'tip' => 'Sets the vertical resolution of the scanned image.',
                              'default' => 'inactive',
                              'values' => '5..600dpi (in steps of 5)'
                            },
          'preview' => {
                         'tip' => 'Request a preview-quality scan.',
                         'default' => 'no',
                         'values' => 'yes|no'
                       },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '100',
                            'values' => '5..300dpi (in steps of 5)'
                          },
          'negative' => {
                          'tip' => 'Swap black and white',
                          'default' => 'inactive',
                          'values' => 'yes|no'
                        },
          'batch-scan-end' => {
                                'tip' => 'set for last scan of batch',
                                'default' => 'inactive',
                                'values' => 'yes|no'
                              },
          'source' => {
                        'tip' => 'Selects the scan source (such as a document-feeder).',
                        'default' => 'Flatbed',
                        'values' => 'Flatbed'
                      },
          'scan-exposure-time' => {
                                    'tip' => 'Define exposure-time for scan',
                                    'default' => 'inactive',
                                    'values' => '0..0us'
                                  },
          'threshold' => {
                           'tip' => 'Select minimum-brightness to get a white point',
                           'default' => 'inactive',
                           'values' => '0..100%'
                         },
          'highlight-r' => {
                             'tip' => 'Selects what red radiance level should be considered "full red".',
                             'default' => '100',
                             'values' => '0..100%'
                           },
          'batch-scan-loop' => {
                                 'tip' => 'set for middle scans of batch',
                                 'default' => 'inactive',
                                 'values' => 'yes|no'
                               },
          'custom-gamma' => {
                              'tip' => 'Determines whether a builtin or a custom gamma-table should be used.',
                              'default' => 'yes',
                              'values' => 'yes|no'
                            },
          'shadow-g' => {
                          'tip' => 'Selects what green radiance level should be considered "black".',
                          'default' => 'inactive',
                          'values' => '0..100%'
                        },
          'batch-scan-start' => {
                                  'tip' => 'set for first scan of batch',
                                  'default' => 'inactive',
                                  'values' => 'yes|no'
                                },
          'batch-scan-next-tl-y' => {
                                      'tip' => 'Set top left Y position for next scan',
                                      'default' => 'inactive',
                                      'values' => '0..297.18mm'
                                    },
          'resolution-bind' => {
                                 'tip' => 'Use same values for X and Y resolution',
                                 'default' => 'yes',
                                 'values' => 'yes|no'
                               },
          'cal-exposure-time-b' => {
                                     'tip' => 'Define exposure-time for blue calibration',
                                     'default' => 'inactive',
                                     'values' => '0..0us'
                                   },
          'highlight-b' => {
                             'tip' => 'Selects what blue radiance level should be considered "full blue".',
                             'default' => '100',
                             'values' => '0..100%'
                           },
          'disable-pre-focus' => {
                                   'tip' => 'Do not calibrate focus',
                                   'default' => 'inactive',
                                   'values' => 'yes|no'
                                 },
          'highlight' => {
                           'tip' => 'Selects what radiance level should be considered "white".',
                           'default' => 'inactive',
                           'values' => '0..100%'
                         },
          'double-res' => {
                            'tip' => 'Use lens that doubles optical resolution',
                            'default' => 'inactive',
                            'values' => 'yes|no'
                          },
          'select-lamp-density' => {
                                     'tip' => 'Enable selection of lamp density',
                                     'default' => 'inactive',
                                     'values' => 'yes|no'
                                   },
          'shadow-b' => {
                          'tip' => 'Selects what blue radiance level should be considered "black".',
                          'default' => 'inactive',
                          'values' => '0..100%'
                        },
          'lamp-off' => {
                          'tip' => 'Turn off scanner lamp',
                          'default' => 'inactive',
                          'values' => ''
                        },
          'cal-exposure-time-g' => {
                                     'tip' => 'Define exposure-time for green calibration',
                                     'default' => 'inactive',
                                     'values' => '0..0us'
                                   },
          'scan-lamp-density' => {
                                   'tip' => 'Define lamp density for scan',
                                   'default' => 'inactive',
                                   'values' => '0..100%'
                                 },
          'analog-gamma-g' => {
                                'tip' => 'Analog gamma-correction for green',
                                'default' => 'inactive',
                                'values' => '1..2 (in steps of 0.00999451)'
                              },
          'contrast' => {
                          'tip' => 'Controls the contrast of the acquired image.',
                          'default' => 'inactive',
                          'values' => '-100..100% (in steps of 1)'
                        },
          'cal-exposure-time' => {
                                   'tip' => 'Define exposure-time for calibration',
                                   'default' => 'inactive',
                                   'values' => '0..0us'
                                 },
          'lamp-off-at-exit' => {
                                  'tip' => 'Turn off lamp when program exits',
                                  'default' => 'inactive',
                                  'values' => 'yes|no'
                                },
          'select-calibration-exposure-time' => {
                                                  'tip' => 'Allow different settings for calibration and scan exposure times',
                                                  'default' => 'inactive',
                                                  'values' => 'yes|no'
                                                },
          'halftone-pattern' => {
                                  'tip' => 'Defines the halftoning (dithering) pattern for scanning halftoned images.',
                                  'default' => 'inactive',
                                  'values' => '0..255'
                                },
          'select-exposure-time' => {
                                      'tip' => 'Enable selection of exposure-time',
                                      'default' => 'inactive',
                                      'values' => 'yes|no'
                                    }
        );
foreach my $option (keys %this) {
 foreach (qw(tip default values)) {
  is ($this{$option}{$_}, $that{$option}{$_}, "$option, $_");
 }
}
eq_hash(\%this, \%that);
