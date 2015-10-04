package Gscan2pdf::PageRange;

use strict;
use warnings;
use Locale::gettext 1.05;    # For translations
use Gtk2;
use Glib qw(TRUE FALSE);     # To get TRUE and FALSE

# Note: in a BEGIN block to ensure that the registration is complete
#       by the time the use Subclass goes to look for it.
BEGIN {
    Glib::Type->register_enum( 'Gscan2pdf::PageRange::Range',
        qw(selected all) );
}

# this big hairy statement registers our Glib::Object-derived class
# and sets up all the signals and properties for it.
use Glib::Object::Subclass Gtk2::VBox::,
  signals    => { changed => {}, },
  properties => [
    Glib::ParamSpec->enum(
        'active',                    # name
        'active',                    # nickname
        'Either selected or all',    #blurb
        'Gscan2pdf::PageRange::Range',
        'selected',                  # default
        [qw/readable writable/]      #flags
    ),
  ];

our $VERSION = '1.3.5';

my @widget_list;

sub INIT_INSTANCE {
    my $self    = shift;
    my $d       = Locale::gettext->domain(Glib::get_application_name);
    my %buttons = (
        'selected' => $d->get('Selected'),
        'all'      => $d->get('All'),
    );
    my $vbox = Gtk2::VBox->new;
    $self->add($vbox);

    #the first radio button has to set the group,
    #which is undef for the first button
    my $group;
    foreach my $nick ( sort keys %buttons ) {
        $self->{button}{$nick} =
          Gtk2::RadioButton->new( $group, $buttons{$nick} );
        $self->{button}{$nick}->signal_connect(
            'toggled' => sub {
                if ( $self->{button}{$nick}->get_active ) {
                    $self->set_active($nick);
                }
            }
        );
        $vbox->pack_start( $self->{button}{$nick}, TRUE, TRUE, 0 );
        if ( not $group ) { $group = $self->{button}{$nick}->get_group }
    }
    push @widget_list, $self;
    return;
}

sub get_active {
    my ($self) = @_;
    return $self->get('active');
}

sub set_active {
    my ( $self, $active ) = @_;
    for my $widget (@widget_list) {
        $widget->{active} = $active;
        for my $nick ( keys %{ $self->{button} } ) {
            if ( $active eq $nick ) {
                $widget->{button}{$nick}->set_active(TRUE);
                $widget->signal_emit('changed');
            }
        }
    }
    return;
}

1;

__END__
