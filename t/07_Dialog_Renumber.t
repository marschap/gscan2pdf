use warnings;
use strict;
use Test::More tests => 14;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;

BEGIN {
    use_ok('Gscan2pdf::Dialog::Renumber');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

my $window = Gtk3::Window->new;

my $slist = Gscan2pdf::Document->new;

ok(
    my $dialog = Gscan2pdf::Dialog::Renumber->new(
        document        => $slist,
        'transient-for' => $window
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Renumber' );

is( $dialog->get('start'),     1, 'default start for empty document' );
is( $dialog->get('increment'), 1, 'default step for empty document' );

#########################

$slist = Gscan2pdf::Document->new;
@{ $slist->{data} } = ( [ 1, undef, undef ], [ 2, undef, undef ] );
$slist->select(1);
my @selected = $slist->get_selected_indices;
is_deeply( \@selected, [1], 'selected' );

$dialog->set( 'range',    'selected' );
$dialog->set( 'document', $slist );
is( $dialog->get('start'),     2, 'start for document with start clash' );
is( $dialog->get('increment'), 1, 'step for document with start clash' );

#########################

@{ $slist->{data} } = (
    [ 1, undef, undef ],
    [ 3, undef, undef ],
    [ 5, undef, undef ],
    [ 7, undef, undef ]
);
$slist->select( 2, 3 );
@selected = $slist->get_selected_indices;
is_deeply( \@selected, [ 2, 3 ], 'selected' );
$dialog->set( 'range', 'selected' );
is( $dialog->get('start'), 4, 'start for document with start and step clash' );
is( $dialog->get('increment'),
    1, 'step for document with start and step clash' );

#########################

$dialog->set( 'increment', 0 );
is( $dialog->get('start'),     4,  'start for document with negative step' );
is( $dialog->get('increment'), -2, 'step for document with negative step' );
$dialog->signal_connect(
    'before-renumber' => sub {
        pass('before-renumber signal fired on renumber');
    }
);
$dialog->renumber;

#########################

Gscan2pdf::Document->quit();

__END__
