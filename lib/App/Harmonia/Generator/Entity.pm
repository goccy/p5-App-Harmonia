package App::Harmonia::Generator::Entity;
use strict;
use warnings;
use parent 'Class::Accessor::Fast';
use App::Harmonia;
use YAML::XS qw/LoadFile/;
use File::Path 'mkpath';
use String::CamelCase qw/camelize/;

__PACKAGE__->mk_accessors(qw/
    schema
    options
/);

sub new {
    my ($class, %options) = @_;
    my $schema = LoadFile 'schema.yaml';
    return bless { schema => $schema, options => \%options }, $class;
}

sub generate {
    my ($self) = @_;
    my $tmpl_code = do { local $/; <DATA> };
    my $application_name = $self->options->{name};
    my $dirname = $self->options->{dirname};
    my $generate_dirname = "$dirname/$application_name/Entity";
    unless (-d $generate_dirname) {
        mkpath($generate_dirname) or die "Cannot create directory $generate_dirname : $!";
    }

    foreach my $table_name (keys %{$self->schema}) {
        my $code = $tmpl_code;
        my $name = camelize $table_name;
        my $tab_space = ' ' x 4;
        my @accessors = keys %{$self->schema->{$table_name}};
        my $accessors = join "\n" . $tab_space, @accessors;
        my $max_name_length = $self->max_name_length(\@accessors);

        $code =~ s/__VERSION__/$App::Harmonia::VERSION/;
        $code =~ s/__CLASS__/$name/g;
        $code =~ s/__ACCESSORS__/$accessors/g;
        my $params = join ",\n" . $tab_space x 2, map {
            $self->mapping_template($table_name, $_, $max_name_length);
        } @accessors;
        my $rules  = join ",\n" . $tab_space, map {
            $self->validation_rule($table_name, $_, $max_name_length);
        } @accessors;
        $code =~ s/__PARAMS__/$params/g;
        $code =~ s/__RULES__/$rules/g;
        $code =~ s/__APP__/$application_name/g;
        open my $fh, '>', "$generate_dirname/$name\.pm";
        print $fh $code;
        close $fh;
        print $code, "\n";
    }
}

sub max_name_length {
    my ($self, $accessors) = @_;
    my $max_length = 0;
    foreach my $accessor (@$accessors) {
        my $length = length $accessor;
        $max_length = $length if ($max_length < $length);
    }
    return $max_length;
}

sub validation_rule {
    my ($self, $table_name, $accessor, $max_name_length) = @_;
    my $length = length $accessor;
    my $arrow_space = ' ' x ($max_name_length - $length);
    my $rule = '';
    my $column = $self->schema->{$table_name}{$accessor};
    my $type = $column->{type};
    $type = 'Str'  if ($type eq 'String');
    $type = 'Num'  if ($type eq 'Number');
    $type = 'Bool' if ($type eq 'Boolean');
    $type = 'Any'  if ($type eq 'Object');
    $type = 'HashRef'  if ($type eq 'Date');
    $type = 'HashRef'  if ($type eq 'File');
    $type = 'HashRef'  if ($type eq 'Pointer');
    $type = 'HashRef'  if ($type eq 'Relation');
    $type = 'ArrayRef' if ($type eq 'Array');
    $rule = $accessor . $arrow_space . " => { isa => '$type' }";
    return $rule;
}

sub mapping_template {
    my ($self, $table_name, $accessor, $max_name_length) = @_;
    my $length = length $accessor;
    my $arrow_space = ' ' x ($max_name_length - $length);
    my $mapping_tmpl;
    if ($accessor eq 'ACL') {
        $mapping_tmpl = '%s' . $arrow_space . ' => __APP__::Core::ACL->new';
    } else {
        $mapping_tmpl = '%s' . $arrow_space . ' => $validated_data->{%s}';
    }
    my $column = $self->schema->{$table_name}{$accessor};
    my $type = $column->{type};
    if ($type eq 'Relation') {
        my $class_name = $column->{className};
        $mapping_tmpl = '%s' . $arrow_space . ' => make_relation({ search_by => make_pointer(bless { object_id => $validated_data->{%s}{object_id} }, \'__CLASS__\'), column => \'__COLUMN__\' })';
        $mapping_tmpl =~ s/__CLASS__/$class_name/;
        $mapping_tmpl =~ s/__COLUMN__/$accessor/;
    }
    return sprintf $mapping_tmpl, $accessor, $accessor;
}

1;

__DATA__
# This code was automatically generated by App::Harmonia (version __VERSION__)

package __APP__::Entity::__CLASS__;
use strict;
use warnings;
use __APP__::Core::ACL;
use parent qw/Class::Accessor::Fast/;
use __APP__::Core::Util qw/make_relation make_pointer/;
use Data::Validator;

__PACKAGE__->mk_accessors(qw/
    __ACCESSORS__
/);

my $validation_rule = Data::Validator->new(
    __RULES__
);

sub new {
    my ($class, $mapping_data) = @_;
    $mapping_data = $mapping_data->{row_data} if (ref($mapping_data) =~ /Fixture/);
    my $validated_data = $mapping_data;
    #my $validated_data = $validation_rule->validate(%$mapping_data);
    return $class->SUPER::new({
        __PARAMS__
    });
}

1;
