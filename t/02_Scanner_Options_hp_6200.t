use warnings;
use strict;
use Test::More tests => 4;
use Image::Sane ':all';     # For enums
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/hp_6200';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
    {
        'index' => 0,
    },
    {
        index             => 1,
        title             => 'Scan mode',
        'cap'             => 0,
        'max_values'      => 0,
        'name'            => '',
        'unit'            => SANE_UNIT_NONE,
        'desc'            => '',
        type              => SANE_TYPE_GROUP,
        'constraint_type' => SANE_CONSTRAINT_NONE
    },
    {
        name  => 'mode',
        title => 'Mode',
        index => 2,
        'desc' =>
          'Selects the scan mode (e.g., lineart, monochrome, or color).',
        'val'           => 'Color',
        'constraint'    => [ 'Lineart', 'Grayscale', 'Color' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => 'resolution',
        title      => 'Resolution',
        index      => 3,
        'desc'     => 'Sets the resolution of the scanned image.',
        'val'      => '75',
        constraint => {
            'min' => 75,
            'max' => 600,
        },
        'unit'          => SANE_UNIT_DPI,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        index             => 4,
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
        name       => 'contrast',
        title      => 'Contrast',
        index      => 5,
        'desc'     => 'Controls the contrast of the acquired image.',
        constraint => {
            'min' => 0,
            'max' => 100,
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
        name  => 'compression',
        title => 'Compression',
        index => 6,
        'desc' =>
'Selects the scanner compression method for faster scans, possibly at the expense of image quality.',
        'val'           => 'JPEG',
        'constraint'    => [ 'None', 'JPEG' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name  => 'jpeg-compression-factor',
        title => 'JPEG compression factor',
        index => 7,
        'desc' =>
'Sets the scanner JPEG compression factor.  Larger numbers mean better compression, and smaller numbers mean better image quality.',
        'val'      => '10',
        constraint => {
            'min' => 0,
            'max' => 100,
        },
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name  => 'batch-scan',
        title => 'Batch scan',
        index => 8,
        'desc' =>
'Guarantees that a "no documents" condition will be returned after the last scanned page, to prevent endless flatbed scans after a batch scan. For some models, option changes in the middle of a batch scan don\'t take effect until after the last page.',
        'val'             => SANE_FALSE,
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'      => 1,
    },
    {
        name  => 'source',
        title => 'Source',
        index => 9,
        'desc' =>
'Selects the desired scan source for models with both flatbed and automatic document feeder (ADF) capabilities.  The "Auto" setting means that the ADF will be used if it\'s loaded, and the flatbed (if present) will be used otherwise.',
        'val'           => 'Auto',
        'constraint'    => [ 'Auto', 'Flatbed', 'ADF' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name  => 'duplex',
        title => 'Duplex',
        index => 10,
        'desc' =>
'Enables scanning on both sides of the page for models with duplex-capable document feeders.  For pages printed in "book"-style duplex mode, one side will be scanned upside-down.  This feature is experimental.',
        'unit'            => SANE_UNIT_NONE,
        'type'            => SANE_TYPE_BOOL,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'      => 1,
        'val'             => SANE_FALSE,
    },
    {
        index             => 11,
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
        name  => 'length-measurement',
        title => 'Length measurement',
        index => 12,
        'desc' =>
'Selects how the scanned image length is measured and reported, which is impossible to know in advance for scrollfed scans.',
        'val'           => 'Padded',
        'constraint'    => [ 'Unknown', 'Approximate', 'Padded' ],
        'unit'          => SANE_UNIT_NONE,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        type            => SANE_TYPE_STRING,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => SANE_NAME_SCAN_TL_X,
        title      => 'Top-left x',
        index      => 13,
        'desc'     => 'Top-left x position of scan area.',
        'val'      => 0,
        constraint => {
            'min' => 0,
            'max' => 215.9,
        },
        'unit'          => SANE_UNIT_MM,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_FIXED,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => SANE_NAME_SCAN_TL_Y,
        title      => 'Top-left y',
        index      => 14,
        'desc'     => 'Top-left y position of scan area.',
        'val'      => 0,
        constraint => {
            'min' => 0,
            'max' => 381,
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
        index      => 15,
        'val'      => 215.9,
        constraint => {
            'min' => 0,
            'max' => 215.9,
        },
        'unit'          => SANE_UNIT_MM,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_FIXED,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    },
    {
        name       => SANE_NAME_SCAN_BR_Y,
        title      => 'Bottom-right y',
        desc       => 'Bottom-right y position of scan area.',
        index      => 16,
        'val'      => 381,
        constraint => {
            'min' => 0,
            'max' => 381,
        },
        'unit'          => SANE_UNIT_MM,
        constraint_type => SANE_CONSTRAINT_RANGE,
        type            => SANE_TYPE_INT,
        'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        'max_values'    => 1,
    }
);
is_deeply( $options->{array}, \@that, 'hp_6200' );
is(
    Gscan2pdf::Scanner::Options->device,
    'hpaio:/usb/Officejet_6200_series?serial=CN4AKCE1ZY0453',
    'device name'
);
is( $options->can_duplex, TRUE, 'can duplex' );
