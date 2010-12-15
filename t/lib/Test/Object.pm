package Test::Object;

use strict;
use warnings;
use Carp qw/confess/;

my $allow_setting = 0;
my $confess_non_existant_fields = 1;

sub import {
    my $class = shift;
    my %args = @_;
    if (exists $args{allow_setting}) {
        $allow_setting = $args{allow_setting};
    }
    if (exists $args{confess_non_existant_fields}) {
        $confess_non_existant_fields = $args{confess_non_existant_fields};
    }
}

sub new {
    my $class = shift;
    my @args = @_;
    if (@args == 1 && ref $args[0] eq 'HASH') {
        return bless $args[0], $class;
    } else {
        my %args = @args;
        return bless \%args, $class;
    }
}

sub AUTOLOAD {
    my $field = our $AUTOLOAD;
    $field =~ s/.*\:\://;
    my $self = shift;
    if ($field eq 'DESTROY') {
        for my $key (keys %$self) {
            delete $self->{$key};
        }
    } else {
        my $value = shift;
        if ($value) {
            if ($allow_setting) {
                $self->{$field} = $value;
            } else {
                confess "Tried to set '$field' to '$value', but 'allow_setting' is 'false' - change this setting at import to prevent this error."
            }
        }
        if (exists $self->{$field}) {
            return $self->{$field};
        } else {
            if ($confess_non_existant_fields) {
                confess "This " . __PACKAGE__ . " doesn't have a $field field";
            }
        }
    }
}

1;
        
