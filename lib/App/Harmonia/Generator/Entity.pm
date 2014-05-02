package App::Harmonia::Generator::Entity;
use strict;
use warnings;
use parent 'Class::Accessor::Fast';
use App::Harmonia;
use YAML::XS qw/LoadFile/;
use File::Path 'mkpath';
use String::CamelCase qw/camelize decamelize/;

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
        my @pointer_accessors  = grep { $self->__is_pointer($table_name, $_) } @accessors;
        my @relation_accessors = grep { $self->__is_relation($table_name, $_) } @accessors;
        my @excluded_pointer_relation_accessors = grep {
            !$self->__is_relation($table_name, $_) && !$self->__is_pointer($table_name, $_)
        } @accessors;
        my @all_accessors = (@excluded_pointer_relation_accessors, map { ("_$_", "cached_$_"); } (@pointer_accessors, @relation_accessors));
        my $accessors = join "\n" . $tab_space, @all_accessors;
        my $max_name_length = $self->max_name_length(\@all_accessors);

        $code =~ s/__VERSION__/$App::Harmonia::VERSION/;
        $code =~ s/__CLASS__/$name/g;
        $code =~ s/__ACCESSORS__/$accessors/g;
        my $params = join ",\n" . $tab_space x 2, map {
            $self->mapping_template($table_name, $_, $max_name_length);
        } (@accessors, 'db');
        my $rules  = join ",\n" . $tab_space, map {
            $self->validation_rule($table_name, $_, $max_name_length);
        } @excluded_pointer_relation_accessors;
        my @extra_modules;
        my $relation_methods = join "\n", map {
            $self->relation_method($table_name, $_, \@extra_modules);
        } @relation_accessors;
        my $pointer_methods = join "\n", map {
            $self->pointer_method($table_name, $_, \@extra_modules);
        } @pointer_accessors;
        my $modules = join "\n", map {
            "use $_;";
        } @extra_modules;
        $code =~ s/__PARAMS__/$params/g;
        $code =~ s/__RULES__/$rules/g;
        $code =~ s/__EXTRA_MODULES__/$modules/;
        $code =~ s/__RELATION_METHODS__/$relation_methods/;
        $code =~ s/__POINTER_METHODS__/$pointer_methods/;
        $code =~ s/__APP__/$application_name/g;
        open my $fh, '>', "$generate_dirname/$name\.pm";
        print $fh $code;
        close $fh;
        #print $code, "\n";
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
    $type = 'Str'      if ($type eq 'String');
    $type = 'Num'      if ($type eq 'Number');
    $type = 'Bool'     if ($type eq 'Boolean');
    $type = 'Any'      if ($type eq 'Object');
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
    } elsif ($accessor eq 'db') {
        $mapping_tmpl = '%s' . $arrow_space . ' => __APP__::Core::DB->new';
    } else {
        $mapping_tmpl = '%s' . $arrow_space . ' => $validated_data->{%s}';
    }
    my $column = $self->schema->{$table_name}{$accessor};
    if ($self->__is_relation($table_name, $accessor)) {
        my $name       = camelize($table_name);
        my $class_name = $column->{className};
        $mapping_tmpl = '%s' . $arrow_space . ' => make_relation({ search_by => make_pointer(bless { object_id => $validated_data->{object_id} }, \'' . $name . '\'), column => \'__COLUMN__\' })';
        $mapping_tmpl =~ s/__CLASS__/$class_name/;
        $mapping_tmpl =~ s/__COLUMN__/$accessor/;
        $accessor = '_' . $accessor;
    } elsif ($self->__is_pointer($table_name, $accessor)) {
        $mapping_tmpl = '%s' . $arrow_space . ' => $validated_data->{' . $accessor . '}';
        $accessor = '_' . $accessor;
    }
    return sprintf $mapping_tmpl, $accessor, $accessor;
}

sub pointer_method {
    my ($self, $table_name, $accessor, $extra_modules) = @_;
    my $column = $self->schema->{$table_name}{$accessor};
    my $class_name  = $column->{className};
    my $column_name = decamelize($class_name);

    my $tmpl =<<'METHOD';
sub __ACCESSOR__ {
    my $self = shift;
    return $self->cached___ACCESSOR__ if ($self->cached___ACCESSOR__);
    my $result = $self->db->single('__COLUMN__', {
        object_id => $self->___ACCESSOR__->{object_id}
    });
    my $blessed_result = __APP__::Entity::__CLASS__->new($result);
    $self->cached___ACCESSOR__($blessed_result);
    return $blessed_result;
}
METHOD
    $tmpl =~ s/__ACCESSOR__/$accessor/g;
    $tmpl =~ s/__CLASS__/$class_name/g;
    $tmpl =~ s/__COLUMN__/$column_name/g;
    push @$extra_modules, '__APP__::Entity::' . $class_name;
    return $tmpl;
}

sub relation_method {
    my ($self, $table_name, $accessor, $extra_modules) = @_;
    my $column = $self->schema->{$table_name}{$accessor};
    my $class_name  = $column->{className};
    my $column_name = decamelize($class_name);

    my $tmpl =<<'METHOD';
sub __ACCESSOR__ {
    my $self = shift;
    return $self->cached___ACCESSOR__ if ($self->cached___ACCESSOR__);
    my $results = $self->db->search('__COLUMN__', {
        related_to => $self->___ACCESSOR__
    });
    my $blessed_results = [ map {
        __APP__::Entity::__CLASS__->new($_);
    } @$results ];
    $self->cached___ACCESSOR__($blessed_results);
    return $blessed_results;
}
METHOD
    $tmpl =~ s/__ACCESSOR__/$accessor/g;
    $tmpl =~ s/__CLASS__/$class_name/g;
    $tmpl =~ s/__COLUMN__/$column_name/g;
    push @$extra_modules, '__APP__::Entity::' . $class_name;
    return $tmpl;
}

sub __is_relation {
    my ($self, $table_name, $accessor) = @_;
    my $column = $self->schema->{$table_name}{$accessor};
    return 0 unless $column;
    my $type = $column->{type};
    return ($type eq 'Relation') ? 1 : 0;
}

sub __is_pointer {
    my ($self, $table_name, $accessor) = @_;
    my $column = $self->schema->{$table_name}{$accessor};
    return 0 unless $column;
    my $type = $column->{type};
    return ($type eq 'Pointer') ? 1 : 0;
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
use __APP__::Core::DB;
use Data::Validator;
__EXTRA_MODULES__

__PACKAGE__->mk_accessors(qw/
    __ACCESSORS__
    db
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

__POINTER_METHODS__
__RELATION_METHODS__

1;
