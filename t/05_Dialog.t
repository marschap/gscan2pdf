use warnings;
use strict;
use Test::More tests => 24;
use Glib qw(TRUE FALSE);     # To get TRUE and FALSE
use Gtk2 -init;
use Scalar::Util;
use Locale::gettext 1.05;    # For translations

BEGIN {
    use_ok('Gscan2pdf::Dialog');
}

#########################

Glib::set_application_name('gscan2pdf');
my $window = Gtk2::Window->new;

ok(
    my $dialog =
      Gscan2pdf::Dialog->new( title => 'title', 'transient-for' => $window ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog' );

is( $dialog->get('title'),         'title', 'title' );
is( $dialog->get('transient-for'), $window, 'transient-for' );
ok( $dialog->get('hide-on-delete') == FALSE, 'default destroy' );
is( $dialog->get('border-width'), 0, 'default border width' );

ok( my $vbox = $dialog->get('vbox'), 'Get vbox' );
isa_ok( $vbox, 'Gtk2::VBox' );
is(
    $vbox->get('border-width'),
    $dialog->get('border-width'),
    'border width applied to vbox'
);

my $border_width = 6;
$dialog->set( 'border-width', $border_width );
is( $dialog->get('border-width'), $border_width, 'set border width' );
is( $vbox->get('border-width'),
    $border_width, 'new border width applied to vbox' );

$dialog = Gscan2pdf::Dialog->new;
$dialog->signal_emit( 'delete_event', undef );
Scalar::Util::weaken($dialog);
is( $dialog, undef, 'destroyed on delete_event' );

$dialog = Gscan2pdf::Dialog->new( 'hide-on-delete' => TRUE );
$dialog->signal_emit( 'delete_event', undef );
Scalar::Util::weaken($dialog);
isnt( $dialog, undef, 'hidden on delete_event' );

$dialog = Gscan2pdf::Dialog->new;
my $event = Gtk2::Gdk::Event->new('key-press');
$event->keyval( $Gtk2::Gdk::Keysyms{Escape} );
$dialog->signal_emit( 'key_press_event', $event );
Scalar::Util::weaken($dialog);
is( $dialog, undef, 'destroyed on escape' );

$dialog = Gscan2pdf::Dialog->new( 'hide-on-delete' => TRUE );
$dialog->signal_emit( 'key_press_event', $event );
Scalar::Util::weaken($dialog);
isnt( $dialog, undef, 'hidden on escape' );

$dialog = Gscan2pdf::Dialog->new;
$dialog->signal_connect_after(
    key_press_event => sub {
        my ( $widget, $event ) = @_;
        is(
            $event->keyval,
            $Gtk2::Gdk::Keysyms{Delete},
            'other key press events still propagate'
        );
    }
);
$event = Gtk2::Gdk::Event->new('key-press');
$event->keyval( $Gtk2::Gdk::Keysyms{Delete} );
$dialog->signal_emit( 'key_press_event', $event );

my %widgets = $dialog->add_metadata_dialog(
    {
        date => {
            today  => [ 2017, 01, 01 ],
            offset => 0,
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
is( $widgets{date}->get_text,     '2017-01-01', 'date' );
is( $widgets{author}->get_text,   'author',     'author' );
is( $widgets{title}->get_text,    'title',      'title' );
is( $widgets{subject}->get_text,  'subject',    'subject' );
is( $widgets{keywords}->get_text, 'keywords',   'keywords' );

is(
    Gscan2pdf::Dialog::filter_message(
'[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.'
    ),
    '[image2 @ %%x] Encoder did not produce proper pts, making some up.',
    'Filter out memory address from unpaper warning'
);

is(
    Gscan2pdf::Dialog::filter_message(
'[image2 @ 0xc596e0] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.'
          . "\n"
          . '[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.'
    ),
'[image2 @ %%x] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.'
      . "\n"
      . '[image2 @ %%x] Encoder did not produce proper pts, making some up.',
    'Filter out double memory address from unpaper warning'
);

__END__
