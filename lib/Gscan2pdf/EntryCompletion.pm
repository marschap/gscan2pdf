package Gscan2pdf::EntryCompletion;

use strict;
use warnings;
use Gtk2;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '1.8.3';

    use base qw(Exporter Gtk2::Entry);
    %EXPORT_TAGS = ();      # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();
}

sub new {
    my ( $class, $default, $suggestions ) = @_;
    my $self       = Gtk2::Entry->new;
    my $completion = Gtk2::EntryCompletion->new;
    $completion->set_inline_completion(TRUE);
    $completion->set_text_column(0);
    $self->set_completion($completion);
    my $model = Gtk2::ListStore->new('Glib::String');
    $completion->set_model($model);

    if ( defined $suggestions ) {
        for my $suggestion ( @{$suggestions} ) {
            $model->set( $model->append, 0, $suggestion );
        }
    }
    $self->set_activates_default(TRUE);
    if ( defined $default ) { $self->set_text($default) }
    bless $self, $class;
    return $self;
}

sub update {
    my ( $self, $suggestions ) = @_;
    my $text       = $self->get_text;
    my $completion = $self->get_completion;
    my $model      = $completion->get_model;
    my $flag       = FALSE;
    my $iter       = $model->get_iter_first;
    while ( defined $iter and not $flag ) {
        my $suggestion = $model->get( $iter, 0 );
        if ( $suggestion eq $text ) { $flag = TRUE }
        $iter = $model->iter_next($iter);
    }
    if ( not $flag ) {
        $model->set( $model->append, 0, $text );
        push @{$suggestions}, $text;
    }
    return $text;
}

1;

__END__
