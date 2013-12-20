package App::Harmonia::Generator;
use strict;
use warnings;
use parent 'Class::Accessor::Fast';
use App::Harmonia::Generator::Entity;
use App::Harmonia::Generator::Core;
use App::Harmonia::Generator::Model;
__PACKAGE__->mk_accessors(qw/
    name
    dirname
/);

sub new {
    my ($class, %args) = @_;
    my $self = {
        name    => $args{name},
        dirname => $args{dirname},
        schema  => $args{schema}
    };
    return $class->SUPER::new($self, $class);
}

sub generate {
    my ($self) = @_;
    App::Harmonia::Generator::Entity->new(
        name    => $self->name,
        dirname => $self->dirname
    )->generate;

    App::Harmonia::Generator::Core->new(
        name    => $self->name,
        dirname => $self->dirname
    )->generate;

    App::Harmonia::Generator::Model->new(
        name    => $self->name,
        dirname => $self->dirname
    )->generate;

}

1;
