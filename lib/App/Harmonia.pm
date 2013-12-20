package App::Harmonia;
use 5.008005;
use strict;
use warnings;
use constant {
    PARSE_URL    => 'https://parse.com',
    DATA_BROWSER => 'https://parse.com/apps/%s/collections'
};
use parent 'Class::Accessor::Fast';
use WWW::Mechanize;
use JSON::XS;
use String::CamelCase qw/decamelize/;
use HTML::Entities qw/decode_entities/;
use YAML::XS qw/Dump/;
use Data::Dumper;
use App::Harmonia::Generator;

__PACKAGE__->mk_accessors(qw/
    mech
    application
    account
    password
    name
    generate_dirname
/);

our $VERSION = "0.01";

sub new {
    my ($class, $options) = @_;
    my $self = {
        application => $options->{application},
        account     => $options->{account},
        password    => $options->{password},
        name        => $options->{name},
        generate_dirname => $options->{generate_dirname},
        mech        => WWW::Mechanize->new
    };
    return $class->SUPER::new($self, $class);
}

sub run {
    my ($self) = @_;
    my $schema_data = $self->generate_schema;
    App::Harmonia::Generator->new(
        name    => $self->name,
        dirname => $self->generate_dirname,
        schema  => $schema_data
    )->generate;
}

sub get_schema {
    my ($self) = @_;
    $self->mech->post(PARSE_URL . '/user_session', {
        'user_session[email]'    => $self->account,
        'user_session[password]' => $self->password
    });
    my $url = sprintf(DATA_BROWSER, $self->application);
    my $content = decode_entities($self->mech->get($url)->decoded_content(charset => 'utf8'));
    my ($id) = $content =~ /var schemaJson = .*\$\('#(.*)'\)/m;
    my ($json) = $content =~ m|$id.*>(.*)</script>|;
    my $schema = decode_json($json);
    return $schema;
}

sub generate_schema {
    my ($self) = @_;
    my $schema = $self->get_schema;
    my $result = {};
    foreach my $table (@$schema) {
        my $table_name = decamelize $table->{className};
        $table_name =~ s/^_//;
        my $cols = $table->{keys};
        foreach my $col_name (keys %$cols) {
            my $params = $cols->{$col_name};
            my $name = ($col_name ne 'ACL') ? decamelize($col_name) : $col_name;
            delete $params->{required};
            $result->{$table_name}->{$name} = $params;
        }
    }
    open my $yaml, '>', 'schema.yaml';
    print $yaml Dump $result;
    close $yaml;
    return $result;
}

1;
__END__

=encoding utf-8

=head1 NAME

App::Harmonia - Generate model layer codes of your application for Parse.com

=head1 SYNOPSIS

    use App::Harmonia;
    App::Harmonia->new({
        name             => 'your application name',
        application      => 'select application type',
        account          => 'your parse.com account',
        password         => 'your parse.com password',
        generate_dirname => 'directory name'
    })->run;

=head1 DESCRIPTION

App::Harmonia generates model layer codes of your application for Parse.com.

=head1 LICENSE

Copyright (C) Masaaki Goshima.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Masaaki Goshima E<lt>goccy54@gmail.comE<gt>

=cut

