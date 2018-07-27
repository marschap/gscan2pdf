use warnings;
use strict;
use Test::More tests => 9;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;
use Scalar::Util;

BEGIN {
    use_ok('Gscan2pdf::Dialog::Save');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
my $window = Gtk3::Window->new;

ok(
    my $dialog = Gscan2pdf::Dialog::Save->new(
        title           => 'title',
        'transient-for' => $window
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Save' );

$dialog->add_metadata(
    {
        date => {
            today  => [ 2017, 01, 01 ],
            offset => 0
        },
        title => {
            default     => 'title',
            suggestions => ['title-suggestion'],
        },
        author => {
            default     => 'author',
            suggestions => ['author-suggestion'],
        },
        subject => {
            default     => 'subject',
            suggestions => ['subject-suggestion'],
        },
        keywords => {
            default     => 'keywords',
            suggestions => ['keywords-suggestion'],
        },
    }
);
is( $dialog->{mdwidgets}{date}->get_text,     '2017-01-01', 'date' );
is( $dialog->{mdwidgets}{author}->get_text,   'author',     'author' );
is( $dialog->{mdwidgets}{title}->get_text,    'title',      'title' );
is( $dialog->{mdwidgets}{subject}->get_text,  'subject',    'subject' );
is( $dialog->{mdwidgets}{keywords}->get_text, 'keywords',   'keywords' );

$dialog = Gscan2pdf::Dialog::Save->new;
$dialog->set( 'include-time', TRUE );
$dialog->add_metadata(
    {
        date => {
            today  => [ 2017, 01, 01 ],
            offset => 0,
            time   => [ 23,   59, 5 ],
            now    => FALSE
        },
    }
);
is(
    $dialog->{mdwidgets}{date}->get_text,
    '2017-01-01 23:59:05',
    'date and time'
);

__END__
