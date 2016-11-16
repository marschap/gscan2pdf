use warnings;
use strict;
use Test::More tests => 19;
use Sane 0.05;    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Profile') }

#########################

is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms(SANE_NAME_PAGE_HEIGHT),
    [ SANE_NAME_PAGE_HEIGHT, 'pageheight' ],
    'synonyms for SANE_NAME_PAGE_HEIGHT'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms('pageheight'),
    [ SANE_NAME_PAGE_HEIGHT, 'pageheight' ],
    'synonyms for pageheight'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms(SANE_NAME_PAGE_WIDTH),
    [ SANE_NAME_PAGE_WIDTH, 'pagewidth' ],
    'synonyms for SANE_NAME_PAGE_WIDTH'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms('pagewidth'),
    [ SANE_NAME_PAGE_WIDTH, 'pagewidth' ],
    'synonyms for pagewidth'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms(SANE_NAME_SCAN_TL_X),
    [ SANE_NAME_SCAN_TL_X, 'l' ],
    'synonyms for SANE_NAME_SCAN_TL_X'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms('l'),
    [ SANE_NAME_SCAN_TL_X, 'l' ],
    'synonyms for l'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms(SANE_NAME_SCAN_TL_Y),
    [ SANE_NAME_SCAN_TL_Y, 't' ],
    'synonyms for SANE_NAME_SCAN_TL_Y'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms('t'),
    [ SANE_NAME_SCAN_TL_Y, 't' ],
    'synonyms for t'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms(SANE_NAME_SCAN_BR_X),
    [ SANE_NAME_SCAN_BR_X, 'x' ],
    'synonyms for SANE_NAME_SCAN_BR_X'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms('x'),
    [ SANE_NAME_SCAN_BR_X, 'x' ],
    'synonyms for x'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms(SANE_NAME_SCAN_BR_Y),
    [ SANE_NAME_SCAN_BR_Y, 'y' ],
    'synonyms for SANE_NAME_SCAN_BR_Y'
);
is_deeply(
    Gscan2pdf::Scanner::Profile::_synonyms('y'),
    [ SANE_NAME_SCAN_BR_Y, 'y' ],
    'synonyms for y'
);

my $profile = Gscan2pdf::Scanner::Profile->new;
isa_ok( $profile, 'Gscan2pdf::Scanner::Profile' );
$profile->add_backend_option( 'y', '297' );
is_deeply(
    $profile->get_data,
    { backend => [ { 'y' => '297' } ] },
    'basic functionality add_backend_option'
);

#########################

$profile->add_backend_option( 'br-y', '297' );
is_deeply(
    $profile->get_data,
    { backend => [ { 'br-y' => '297' } ] },
    'pruned duplicate'
);

#########################

$profile->add_frontend_option( 'num_pages', 0 );
is_deeply(
    $profile->get_data,
    { backend => [ { 'br-y' => '297' } ], frontend => { 'num_pages' => 0 } },
    'basic functionality add_frontend_option'
);

#########################

$profile = Gscan2pdf::Scanner::Profile->new_from_data(
    { backend => [ { 'br-x' => '297' } ], frontend => { 'num_pages' => 1 } } );
is_deeply(
    $profile->get_data,
    { backend => [ { 'br-x' => '297' } ], frontend => { 'num_pages' => 1 } },
    'basic functionality new_from_data'
);

#########################

$profile = Gscan2pdf::Scanner::Profile->new_from_data(
    { backend => [ { l => 1 }, { y => 50 }, { x => 50 }, { t => 2 } ] } );
is_deeply(
    $profile->get_data,
    {
        backend => [
            { 'tl-x' => 1 },
            { 'br-y' => 52 },
            { 'br-x' => 51 },
            { 'tl-y' => 2 }
        ]
    },
    'basic functionality map_from_cli'
);
