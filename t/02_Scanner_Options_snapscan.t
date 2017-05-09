use warnings;
use strict;
use Test::More tests => 3;
use Image::Sane ':all';    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/snapscan';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
    {
        'index' => 0,
    },
    {
        index             => 1,
        title             => 'Scan Mode',
        'cap'             => 0,
        'max_values'      => 0,
        'name'            => '',
        'unit'            => SANE_UNIT_NONE,
        'desc'            => '',
        type              => SANE_TYPE_GROUP,
        'constraint_type' => SANE_CONSTRAINT_NONE
    },
    {
        name   => 'resolution',
        title  => 'Resolution',
        index  => 2,
        'desc' => 'Sets the resolution of the scanned image.',
        'val'  => '300',
        'constraint' =>
          [ '50', '75', '100', '150', '200', '300', '450', '600' ],
        'unit'          => SANE_UNIT_DPI,
        constraint_type => SANE_CONSTRAINT_WORD_LIST,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_AUTOMATIC,
        'max_values' => 1,
    },
    {
        name              => 'preview',
        title             => 'Preview',
        index             => 3,
        'desc'            => 'Request a preview-quality scan.',
        'val'             => SANE_FALSE,
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_AUTOMATIC,
        'max_values' => 1,
    },
    {
        name  => 'mode',
        title => 'Mode',
        index => 4,
        'desc' =>
          'Selects the scan mode (e.g., lineart, monochrome, or color).',
        'val'           => 'Color',
        'constraint'    => [ 'Color', 'Halftone', 'Gray', 'Lineart' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_AUTOMATIC,
        'max_values' => 1,
    },
    {
        name  => 'preview-mode',
        title => 'Preview mode',
        index => 5,
        'desc' =>
'Select the mode for previews. Greyscale previews usually give the best combination of speed and detail.',
        'val'           => 'Auto',
        'constraint'    => [ 'Auto', 'Color', 'Halftone', 'Gray', 'Lineart' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_AUTOMATIC,
        'max_values' => 1,
    },
    {
        name              => 'high-quality',
        title             => 'High quality',
        index             => 6,
        'desc'            => 'Highest quality but lower speed',
        'val'             => SANE_FALSE,
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_AUTOMATIC,
        'max_values' => 1,
    },
    {
        name         => 'source',
        title        => 'Source',
        index        => 7,
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'constraint' => ['Flatbed'],
        'unit'       => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE +
          SANE_CAP_AUTOMATIC,
        'max_values' => 1,
    },
    {
        index             => 8,
        title             => 'Geometry',
        'cap'             => 0,
        'max_values'      => 0,
        'name'            => '',
        'unit'            => SANE_UNIT_NONE,
        'desc'            => '',
        type              => SANE_TYPE_GROUP,
        'constraint_type' => SANE_CONSTRAINT_NONE
    },
    {
        name       => SANE_NAME_SCAN_TL_X,
        title      => 'Top-left x',
        index      => 9,
        'desc'     => 'Top-left x position of scan area.',
        'val'      => 0,
        constraint => {
            'min' => 0,
            'max' => 216,
        },
        'unit'          => SANE_UNIT_MM,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => SANE_NAME_SCAN_TL_Y,
        title      => 'Top-left y',
        index      => 10,
        'desc'     => 'Top-left y position of scan area.',
        'val'      => 0,
        constraint => {
            'min' => 0,
            'max' => 297,
        },
        'unit'          => SANE_UNIT_MM,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => SANE_NAME_SCAN_BR_X,
        title      => 'Bottom-right x',
        desc       => 'Bottom-right x position of scan area.',
        index      => 11,
        'val'      => 216,
        constraint => {
            'min' => 0,
            'max' => 216,
        },
        'unit'          => SANE_UNIT_MM,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => SANE_NAME_SCAN_BR_Y,
        title      => 'Bottom-right y',
        desc       => 'Bottom-right y position of scan area.',
        index      => 12,
        'val'      => 297,
        constraint => {
            'min' => 0,
            'max' => 297,
        },
        'unit'          => SANE_UNIT_MM,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name  => 'predef-window',
        title => 'Predef window',
        index => 13,
        'desc' =>
'Provides standard scanning areas for photographs, printed pages and the like.',
        'val' => 'None',
        'constraint' =>
          [ 'None', '6x4 (inch)', '8x10 (inch)', '8.5x11 (inch)' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        index             => 14,
        title             => 'Enhancement',
        'cap'             => 0,
        'max_values'      => 0,
        'name'            => '',
        'unit'            => SANE_UNIT_NONE,
        'desc'            => '',
        type              => SANE_TYPE_GROUP,
        'constraint_type' => SANE_CONSTRAINT_NONE
    },
    {
        name  => 'depth',
        title => 'Depth',
        index => 15,
        'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
        'constraint'    => ['8'],
        'unit'          => SANE_UNIT_BIT,
        constraint_type => SANE_CONSTRAINT_WORD_LIST,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 1,
    },
    {
        name              => 'quality-cal',
        title             => 'Quality cal',
        index             => 16,
        'desc'            => 'Do a quality white-calibration',
        'val'             => SANE_TRUE,
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'      => 1,
    },
    {
        name  => 'halftoning',
        title => 'Halftoning',
        index => 17,
        'desc' =>
          'Selects whether the acquired image should be halftoned (dithered).',
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 1,
    },
    {
        name  => 'halftone-pattern',
        title => 'Halftone pattern',
        index => 18,
        'desc' =>
'Defines the halftoning (dithering) pattern for scanning halftoned images.',
        'constraint'    => [ 'DispersedDot8x8', 'DispersedDot16x16' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 1,
    },
    {
        name  => 'custom-gamma',
        title => 'Custom gamma',
        index => 19,
        'desc' =>
'Determines whether a builtin or a custom gamma-table should be used.',
        'val'             => SANE_FALSE,
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'      => 1,
    },
    {
        name              => 'analog-gamma-bind',
        title             => 'Analog gamma bind',
        index             => 20,
        'desc'            => 'In RGB-mode use same values for each color',
        'val'             => SANE_FALSE,
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'      => 1,
    },
    {
        name       => 'analog-gamma',
        title      => 'Analog gamma',
        index      => 21,
        'desc'     => 'Analog gamma-correction',
        constraint => {
            'min' => 0,
            'max' => 4,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 1,
    },
    {
        name       => 'analog-gamma-r',
        title      => 'Analog gamma r',
        index      => 22,
        'desc'     => 'Analog gamma-correction for red',
        'val'      => '1.79999',
        constraint => {
            'min' => 0,
            'max' => 4,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_FIXED,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => 'analog-gamma-g',
        title      => 'Analog gamma g',
        index      => 23,
        'desc'     => 'Analog gamma-correction for green',
        'val'      => '1.79999',
        constraint => {
            'min' => 0,
            'max' => 4,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_FIXED,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => 'analog-gamma-b',
        title      => 'Analog gamma b',
        index      => 24,
        'desc'     => 'Analog gamma-correction for blue',
        'val'      => '1.79999',
        constraint => {
            'min' => 0,
            'max' => 4,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_FIXED,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name  => 'gamma-table',
        title => 'Gamma table',
        index => 25,
        'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
        constraint => {
            'min'   => 0,
            'max'   => 65535,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 255,
    },
    {
        name       => 'red-gamma-table',
        title      => 'Red gamma table',
        index      => 26,
        'desc'     => 'Gamma-correction table for the red band.',
        constraint => {
            'min'   => 0,
            'max'   => 65535,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 255,
    },
    {
        name       => 'green-gamma-table',
        title      => 'Green gamma table',
        index      => 27,
        'desc'     => 'Gamma-correction table for the green band.',
        constraint => {
            'min'   => 0,
            'max'   => 65535,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 255,
    },
    {
        name       => 'blue-gamma-table',
        title      => 'Blue gamma table',
        index      => 28,
        'desc'     => 'Gamma-correction table for the blue band.',
        constraint => {
            'min'   => 0,
            'max'   => 65535,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 255,
    },
    {
        name              => 'negative',
        title             => 'Negative',
        index             => 29,
        'desc'            => 'Swap black and white',
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE +
          SANE_CAP_AUTOMATIC,
        'max_values' => 1,
    },
    {
        name       => 'threshold',
        title      => 'Threshold',
        index      => 30,
        'desc'     => 'Select minimum-brightness to get a white point',
        constraint => {
            'min'   => 0,
            'max'   => 100,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_PERCENT,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 1,
    },
    {
        name       => 'brightness',
        title      => 'Brightness',
        index      => 31,
        'desc'     => 'Controls the brightness of the acquired image.',
        'val'      => '0',
        constraint => {
            'min'   => -400,
            'max'   => 400,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_PERCENT,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => 'contrast',
        title      => 'Contrast',
        index      => 32,
        'desc'     => 'Controls the contrast of the acquired image.',
        'val'      => '0',
        constraint => {
            'min'   => -100,
            'max'   => 400,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_PERCENT,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        index             => 33,
        title             => 'Advanced',
        'cap'             => 0,
        'max_values'      => 0,
        'name'            => '',
        'unit'            => SANE_UNIT_NONE,
        'desc'            => '',
        type              => SANE_TYPE_GROUP,
        'constraint_type' => SANE_CONSTRAINT_NONE
    },
    {
        name  => 'rgb-lpr',
        title => 'Rgb lpr',
        index => 34,
        'desc' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
        'val'      => '4',
        constraint => {
            'min'   => 1,
            'max'   => 50,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name  => 'gs-lpr',
        title => 'Gs lpr',
        index => 35,
        'desc' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
        constraint => {
            'min'   => 1,
            'max'   => 50,
            'quant' => 1,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        'max_values' => 1,
    },
);
is_deeply( $options->{array}, \@that, 'snapscan' );
is( Gscan2pdf::Scanner::Options->device,
    'snapscan:/dev/uscanner0', 'device name' );
