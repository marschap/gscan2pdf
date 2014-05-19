use warnings;
use strict;
use Test::More tests => 3;
use Sane 0.05;    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/brother';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
    {
        index => 0,
    },
    {
        name              => '',
        index             => 1,
        title             => 'Mode',
        cap               => 0,
        type              => SANE_TYPE_GROUP,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'unit'            => SANE_UNIT_NONE,
        'max_values'      => 0,
        'desc'            => '',
    },
    {
        name         => 'mode',
        title        => 'Mode',
        'cap'        => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        index        => 2,
        'desc'       => 'Select the scan mode',
        'val'        => '24bit Color',
        'constraint' => [
            'Black & White',
            'Gray[Error Diffusion]',
            'True Gray',
            '24bit Color',
            '24bit Color[Fast]'
        ],
        'type'          => SANE_TYPE_STRING,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        'unit'          => SANE_UNIT_NONE,
        'max_values'    => 1,
    },
    {
        name         => 'resolution',
        title        => 'Resolution',
        'cap'        => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        index        => 3,
        'desc'       => 'Sets the resolution of the scanned image.',
        'val'        => '200',
        'constraint' => [
            '100',  '150',  '200',  '300', '400', '600',
            '1200', '2400', '4800', '9600'
        ],
        'type'          => SANE_TYPE_INT,
        constraint_type => SANE_CONSTRAINT_WORD_LIST,
        'unit'          => SANE_UNIT_DPI,
        'max_values'    => 1,
    },
    {
        name         => 'source',
        title        => 'Source',
        'cap'        => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        index        => 4,
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'val'        => 'Automatic Document Feeder',
        'constraint' => [ 'FlatBed', 'Automatic Document Feeder' ],
        'type'       => SANE_TYPE_STRING,
        constraint_type => SANE_CONSTRAINT_STRING_LIST,
        'unit'          => SANE_UNIT_NONE,
        'max_values'    => 1,
    },
    {
        name  => 'brightness',
        title => 'Brightness',
        'cap' => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        index      => 5,
        'desc'     => 'Controls the brightness of the acquired image.',
        constraint => {
            'min'   => -50,
            'max'   => 50,
            'quant' => 1,
        },
        'type'          => SANE_TYPE_INT,
        constraint_type => SANE_CONSTRAINT_RANGE,
        'unit'          => SANE_UNIT_PERCENT,
        'max_values'    => 1,
    },
    {
        name  => 'contrast',
        title => 'Contrast',
        'cap' => SANE_CAP_SOFT_DETECT +
          SANE_CAP_SOFT_SELECT +
          SANE_CAP_INACTIVE,
        index      => 6,
        'desc'     => 'Controls the contrast of the acquired image.',
        constraint => {
            'min'   => -50,
            'max'   => 50,
            'quant' => 1,
        },
        'type'          => SANE_TYPE_INT,
        constraint_type => SANE_CONSTRAINT_RANGE,
        'unit'          => SANE_UNIT_PERCENT,
        'max_values'    => 1,
    },
    {
        name              => '',
        index             => 7,
        title             => 'Geometry',
        cap               => 0,
        type              => SANE_TYPE_GROUP,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'unit'            => SANE_UNIT_NONE,
        'max_values'      => 0,
        'desc'            => '',
    },
    {
        name       => 'l',
        title      => 'Top-left x',
        'cap'      => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        index      => 8,
        'desc'     => 'Top-left x position of scan area.',
        'val'      => 0,
        constraint => {
            'min'   => 0,
            'max'   => 210,
            'quant' => 0.0999908,
        },
        'type'          => SANE_TYPE_FIXED,
        constraint_type => SANE_CONSTRAINT_RANGE,
        'unit'          => SANE_UNIT_MM,
        'max_values'    => 1,
    },
    {
        name       => 't',
        title      => 'Top-left y',
        'cap'      => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        index      => 9,
        'desc'     => 'Top-left y position of scan area.',
        'val'      => 0,
        constraint => {
            'min'   => 0,
            'max'   => 297,
            'quant' => 0.0999908,
        },
        'type'          => SANE_TYPE_FIXED,
        constraint_type => SANE_CONSTRAINT_RANGE,
        'unit'          => SANE_UNIT_MM,
        'max_values'    => 1,
    },
    {
        name       => 'x',
        title      => 'Width',
        'cap'      => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        index      => 10,
        'desc'     => 'Width of scan-area.',
        'val'      => 209.981,
        constraint => {
            'min'   => 0,
            'max'   => 210,
            'quant' => 0.0999908,
        },
        'type'          => SANE_TYPE_FIXED,
        constraint_type => SANE_CONSTRAINT_RANGE,
        'unit'          => SANE_UNIT_MM,
        'max_values'    => 1,
    },
    {
        name       => 'y',
        title      => 'Height',
        'cap'      => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
        index      => 11,
        'desc'     => 'Height of scan-area.',
        'val'      => 296.973,
        constraint => {
            'min'   => 0,
            'max'   => 297,
            'quant' => 0.0999908,
        },
        'type'          => SANE_TYPE_FIXED,
        constraint_type => SANE_CONSTRAINT_RANGE,
        'unit'          => SANE_UNIT_MM,
        'max_values'    => 1,
    }
);
is_deeply( $options->{array}, \@that, 'brother' );
is( Gscan2pdf::Scanner::Options->device, 'brother2:net1;dev0', 'device name' );
