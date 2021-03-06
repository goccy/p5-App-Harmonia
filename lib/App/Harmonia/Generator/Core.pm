package App::Harmonia::Generator::Core;
use strict;
use warnings;
use parent 'Class::Accessor::Fast';
use App::Harmonia;
use YAML::XS qw/LoadFile/;
use File::Path 'mkpath';
use String::CamelCase qw/camelize/;
use Data::Section::Simple qw/get_data_section/;
use File::Basename qw/dirname/;

__PACKAGE__->mk_accessors(qw/
    schema
    options
/);

my @CORE_PACKAGE_LIST = qw{
    Config
    Util
    Date
    File
    ACL
    Relation
    ParallelExecutor
    Logger
    Fixture
    DB
    DB/Engine
    DB/Engine/Fixture
    DB/Engine/Fixture/Schema
    DB/Engine/ParseCom
    DB/Engine/ParseCom/Util
    DB/Engine/ParseCom/RequestBuilder
    DB/Engine/ParseCom/RequestBuilder/Header
    DB/Engine/ParseCom/RequestBuilder/URL
    DB/Engine/ParseCom/RequestBuilder/Body
    DB/Engine/ParseCom/ResponseBuilder
    DB/Engine/ParseCom/ResponseBuilder/Error
};

sub new {
    my ($class, %options) = @_;
    my $schema = LoadFile 'schema.yaml';
    return bless { schema => $schema, options => \%options }, $class;
}

sub generate {
    my ($self) = @_;
    my $application_name = $self->options->{name};
    my $dirname = $self->options->{dirname};
    my $generate_dirname = "$dirname/$application_name/Core";

    unless (-d $generate_dirname) {
        mkpath($generate_dirname) or die "Cannot create directory $generate_dirname : $!";
    }

    foreach my $name (@CORE_PACKAGE_LIST) {
        my $code = get_data_section($name);
        $code =~ s/__VERSION__/$App::Harmonia::VERSION/;
        $code =~ s/__APP__/$application_name/g;
        my $dirname = dirname "$generate_dirname/$name\.pm";
        unless (-d $dirname) {
            mkpath($dirname) or die "Cannot create directory $dirname : $!";
        }
        open my $fh, '>', "$generate_dirname/$name\.pm";
        print $fh $code;
        close $fh;
    }
}

1;

__DATA__

@@ Config
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::Config;
use strict;
use warnings;
use parent 'Exporter';
use Scope::Guard;
use YAML::XS qw/LoadFile/;
use constant SECRET_KEY_FILE => 'secret_keys.yaml';

our @EXPORT_OK = qw/
    init_config_for_development
/;

our $HEADER;
our $MASTER_KEY;
our $REST_API_KEY;
our $APPLICATION_ID;
our $SESSION_TOKEN;
our $USE_MASTER_KEY = 0;

sub new {
    my ($class, $header) = @_;
    $HEADER = $header;
    my $h = $header->{headers};
    $MASTER_KEY = $h->{'x-parse-master-key'}->[0]->[0];
    $APPLICATION_ID = $h->{'x-parse-application-id'}->[0]->[0];
    $SESSION_TOKEN = $h->{'x-parse-session-token'}->[0]->[0];
    return bless({}, $class);
}

sub init_config_for_development {
    my (%param) = @_;
    load_keys();
    $USE_MASTER_KEY = $param{use_rest_api_key} ? 0 : 1;
    return Scope::Guard->new(sub {
        $MASTER_KEY     = '';
        $APPLICATION_ID = '';
        $USE_MASTER_KEY = 0;
        $REST_API_KEY   = '';
    });
}

sub load_keys {
    my $secret_keys = LoadFile SECRET_KEY_FILE;
    my $env = $ENV{PLACK_ENV};
    if ($env eq 'production') {
        $MASTER_KEY     = $secret_keys->{production}{master_key};
        $APPLICATION_ID = $secret_keys->{production}{application_id};
        $REST_API_KEY   = $secret_keys->{production}{rest_api_key};
    } elsif ($env eq 'staging') {
        $MASTER_KEY     = $secret_keys->{production}{master_key};
        $APPLICATION_ID = $secret_keys->{production}{application_id};
        $REST_API_KEY   = $secret_keys->{production}{rest_api_key};
    } elsif ($env eq 'development') {
        $MASTER_KEY     = $secret_keys->{staging}{master_key};
        $APPLICATION_ID = $secret_keys->{staging}{application_id};
        $REST_API_KEY   = $secret_keys->{staging}{rest_api_key};
    } else {
        die "unknown environment. set $ENV{PLACK_ENV}";
    }
}

1;

@@ Util
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::Util;
use strict;
use warnings;
use __APP__::Core::Relation;
use parent 'Exporter';

our @EXPORT_OK = qw/
    make_pointer
    make_relation
    make_date
    make_file
/;

sub new {
    my ($class) = @_;
    return bless({}, $class);
}

sub make_pointer {
    my ($object) = @_;
    unless (defined $object->{object_id}) {
        die 'cannot create pointer from unknown object';
    }
    my $id = $object->{object_id};
    my $class = ref $object;
    $class =~ s/.*:://;
    $class =~ s/^User$/_User/;
    $class =~ s/^Role$/_Role/;
    $class =~ s/^Installation$/_Installation/;
    return {
        '__type'    => 'Pointer',
        'className' => $class,
        'objectId'  => $id
    };
}

sub make_relation {
    my ($args) = @_;
    return __APP__::Core::Relation->new($args);
}

sub make_date {
    my ($date) = @_;
    return {
        '__type' => 'Date',
        'iso'    => $date
    };
}

sub make_file {
    my ($filename) = @_;
    return +{
        '__type' => 'File',
        'name'   => $filename
    };
}

1;

@@ Date
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::Date;
use strict;
use warnings;
use DateTime::Format::Strptime;
use DateTime;
use Data::Dumper;
use parent qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/
    time
/);

sub new {
    my ($class, $created_at) = @_;
    my $self = $class->SUPER::new();
    my $time;
    if (defined $created_at) {
        my $strp = DateTime::Format::Strptime->new(
            pattern => '%Y-%m-%dT%H:%M:%S'
        );
        $time = $strp->parse_datetime($created_at);
        unless (defined $time) {
            $strp = DateTime::Format::Strptime->new(
                pattern => '%Y-%m-%d'
            );
            $time = $strp->parse_datetime($created_at);
        }
    } else {
        $time = DateTime->now(time_zone => 'local');
    }
    $self->{time} = $time;
    return bless($self, $class);
}

sub beginning_of_month {
    my ($self) = @_;
    my $time = $self->time;
    my $beginning_of_month = DateTime->new(
        year       => $time->year,
        month      => $time->month,
        day        => 1,
        hour       => 0,
        minute     => 0,
        second     => 0,
    );
    return $self->raw_time($beginning_of_month);
}

sub next_day {
    my ($self) = @_;
    my $cur_day = $self->time->clone();
    return $self->raw_time($cur_day->add(days => 1));
}

sub prev_day {
    my ($self) = @_;
    my $cur_day = $self->time->clone();
    return $self->raw_time($cur_day->add(days => -1));
}

sub duration {
    my ($self, $to_day) = @_;
    my $cur_day = $self->time->clone;
    my @ret;
    my $duration = $to_day->time->delta_days($cur_day);
    my $duration_num = $duration->delta_days;
    for (1 .. $duration_num) {
        $cur_day->add(days => 1);
        my $added_day = $cur_day->clone;
        $added_day->subtract(hours => 9);
        push @ret, $self->raw_time($added_day);
    }
    return \@ret;
}

sub raw_time {
    my ($self, $time) = @_;
    return sprintf("%sT%s.000Z", $time->ymd(), $time->hms());
}

sub raw {
    my ($self) = shift;
    return sprintf("%sT%s", $self->time->ymd(), $self->time->hms());
}

sub convert_to_us_time_zone {
    my ($self, $time) = shift;
    my $cloned_time = (defined $time) ? $time->clone : $self->time->clone;
    $cloned_time->subtract(hours => 9);
    return $cloned_time;
}

sub convert_to_jp_time_zone {
    my ($self, $time) = shift;
    my $cloned_time = (defined $time) ? $time->clone : $self->time->clone;
    $cloned_time->add(hours => 9);
    return $cloned_time;
}

sub is_inner_this_month {
    my ($self) = @_;
    my $time = $self->time;
    my $target_time = $time->epoch;
    my $beginning_of_month = DateTime->new(
        year       => $time->year,
        month      => $time->month,
        day        => 1,
        hour       => 0,
        minute     => 0,
        second     => 0,
    );
    my $beginning_of_month_time = $beginning_of_month->epoch;
    return ($beginning_of_month_time < $target_time) ? 1 : 0;
}

1;

@@ File
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::File;
use strict;
use warnings;
use Imager;
use parent qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/
    filename
    type
    imager
/);

sub new {
    my ($class, $filename) = @_;
    $filename ||= '';
    my $type = '';
    if ($filename) {
        my ($ext) = $filename =~ /\.(.+)$/;
        if ($ext =~ /(jpg|jpeg)/i) {
            $type = 'jpeg';
        } elsif ($ext =~ /png/i) {
            $type = 'png';
        }
    }
    my $imager = ($filename) ? Imager->new(file => $filename) : Imager->new;
    return $class->SUPER::new({
        filename => $filename,
        imager   => $imager,
        type     => $type
    });
}

sub set_binary_data {
    my ($self, $args) = @_;
    return 0 unless ($args);
    return 0 unless ($args->{data});
    return 0 unless ($args->{type});
    $self->type($args->{type});
    $self->imager->read(data => $args->{data}, type => $args->{type})
        or die $self->imager->errstr;
    return 1;
}

sub binary_data {
    my ($self) = @_;
    my $binary_data;
    $self->imager->write(data => \$binary_data, type => $self->type)
        or die $self->imager->errstr;
    return $binary_data;
}

sub content_type {
    my ($self) = @_;
    return 'image/' . $self->type;
}

1;

@@ Relation
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::Relation;
use strict;
use warnings;
use parent qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/
    search_by
    column
    objects
/);

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new({
        search_by => $args->{search_by},
        column    => $args->{column},
        objects   => []
    });
    return bless($self, $class);
}

sub add {
    my ($self, $ptr) = @_;
    push @{$self->objects}, $ptr;
}

sub __raw {
    my ($self) = @_;
    if (defined $self->search_by && defined $self->column) {
        return {
            'object' => $self->search_by,
            'key'    => $self->column
        };
    } else {
        return {
            '__op' => 'AddRelation',
            'objects' => $self->objects
        };
    }
}

1;

@@ ACL
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::ACL;
use strict;
use warnings;

sub new {
    my ($class, $user) = @_;
    my $self = {
        role_access_status => {},
        user_access_status => {}
    };
    return bless $self, $class unless (defined $user);
    return bless $self, $class unless (defined $user->{acl});
    my $acl = $user->{acl};
    foreach my $key (keys %$acl) {
        if ($key =~ /role/) {
            my ($user_id) = $key =~ /^role:(.+)$/;
            $self->{role_access_status}->{$user_id} = $acl->{$key};
        } else {
            $self->{user_access_status}->{$key} = $acl->{$key};
        }
    }
    return bless($self, $class);
}

sub set_original_acl {
    my ($class, $object) = @_;
    my $self = {
        role_access_status => {},
        user_access_status => {}
    };
    return bless $self, $class unless (defined $object);
    return bless $self, $class unless (defined $object->{ACL});
    my $original_acl = $object->{ACL};
    for my $key ( keys( $original_acl ) ) {
        my $access = $original_acl->{$key};
        if ($key =~ /^role:(.+)$/) {
            $self->{role_access_status}->{$1} = $access;
        }
        else {
            $self->{user_access_status}->{$key} = $access;
        }
    }

    return bless($self, $class);
}

sub set_allow_all_access {
    my ($self, $user_object_id, $role_object_id) = @_;
    $self->{role_access_status} = +{
        $role_object_id => {
            read  => \1,
            write => \1
        }
    };
    $self->{user_access_status} = +{
        $user_object_id => {
            read  => \1,
            write => \1
        }
    };
}

sub set_user_read_access {
    my ($self, $id, $status) = @_;
    my $access = ($status) ? \1 : \0;
    unless ( $self->has_user_acl($id) ) {
        $self->{user_access_status}->{$id} = { read => $access };
    } else {
        $self->{user_access_status}->{$id}->{read} = $access;
    }
}

sub set_user_write_access {
    my ($self, $id, $status) = @_;
    my $access = ($status) ? \1 : \0;
    unless ( $self->has_user_acl($id) ) {
        $self->{user_access_status}->{$id} = { write => $access };
    } else {
        $self->{user_access_status}->{$id}->{write} = $access;
    }
}

sub set_role_read_access {
    my ($self, $role_name, $status) = @_;
    my $access = ($status) ? \1 : \0;
    unless ($self->has_role_acl($role_name)) {
        $self->{role_access_status}->{$role_name} = { read => $access };
    } else {
        $self->{role_access_status}->{$role_name}->{read} = $access;
    }
}

sub set_role_write_access {
    my ($self, $role_name, $status) = @_;
    my $access = ($status) ? \1 : \0;
    unless ($self->has_role_acl($role_name)) {
        $self->{role_access_status}->{$role_name} = { write => $access };
    } else {
        $self->{role_access_status}->{$role_name}->{write} = $access;
    }
}

sub has_user_acl {
    my ($self, $user_id) = @_;
    return exists($self->{user_access_status}->{$user_id});
}

sub has_role_acl {
    my ($self, $role_name) = @_;
    return exists($self->{role_access_status}->{$role_name});
}

sub raw {
    my ($self) = @_;
    my $access = {};
    for my $role_id (keys %{$self->{role_access_status}}) {
        $access->{"role:$role_id"} = $self->{role_access_status}->{$role_id};
    }
    for my $user_id (keys %{$self->{user_access_status}}) {
        $access->{$user_id} = $self->{user_access_status}->{$user_id};
    }
    return $access;
}

sub remove_role {
    my ($self, $role_name) = @_;
    delete($self->{role_access_status}->{$role_name}) if ($self->has_role_acl($role_name));
}

1;

@@ ParallelExecutor
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::ParallelExecutor;
use strict;
use warnings;
use Coro;
use Coro::Select;
use Coro::LWP;
use List::MoreUtils qw/part/;
use parent 'Exporter';

our @EXPORT_OK = qw/
    parallel_run
    parallel_run_with_thread_number
/;

sub parallel_run(&@) {
    my ($handler, @array) = @_;
    my @results;
    my @coros;
    foreach my $elem (@array) {
        push @coros, async {
            $_ = $elem;
            push @results, &$handler;
        };
    }
    $_->join foreach @coros;
    return @results;
}

sub parallel_run_with_thread_number {
    my ($thread_number, $handler, @array) = @_;
    my @coros;
    my $idx = 0;
    my @part_array = part { $idx++ % $thread_number } @array;
    my @results;
    for (my $idx = 0; $idx < $thread_number; $idx++) {
        push @coros, async {
            my $sub_array = shift @part_array;
            push @results, &$handler($idx, $sub_array);
        };
    }
    $_->join foreach @coros;
    return @results;
}

1;

@@ Logger
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::Logger;
use strict;
use warnings;
use constant BASE_DIR => 'logs/';
use JSON::XS;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub error_log {
    my ($self, $msg) = @_;
    warn $msg;
    open my $fh, '>>', BASE_DIR . 'error.log';
    print $fh sprintf('[%s] : %s', time, $msg);
    close $fh;
}

sub logging {
    my ($self, $log) = @_;
    my $event_name = $log->{event_name};
    my $body = encode_json($log->{body});
    open my $fh, '>>', BASE_DIR . "$event_name\.log";
    print $fh $log->{type} . ' : ';
    print $fh $body;
    print $fh "\n";
    close $fh;
    warn "[EVENT]: $event_name [BODY] : $body";
}

1;

@@ Fixture
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::Fixture;
use strict;
use warnings;

sub import {
    my ($class, @args) = @_;
    $ENV{PLACK_ENV} = 'testing';
    $ENV{FIXTURE_DB} = 'Fixture';
    $ENV{FIXTURED_DATAS} = join ' ', @args if (@args);
}

1;

@@ DB
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB;
use strict;
use warnings;
use __APP__::Core::DB::Engine;

sub new {
    my ($class, $db_name) = @_;
    my $engine_name = $db_name || 'ParseCom';
    return __APP__::Core::DB::Engine->new($engine_name);
}

1;

@@ DB/Engine
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine;
use strict;
use warnings;

sub new {
    my ($class, $engine_name) = @_;
    my $engine = '__APP__/Core/DB/Engine/' . $engine_name;
    require "$engine.pm";
    $engine =~ s|/|::|g;
    return $engine->new;
}

1;

@@ DB/Engine/Fixture
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::Fixture;
use strict;
use warnings;
use Test::mysqld;
use DBIx::Skinny;
use DBIx::FixtureLoader;
use File::Temp qw/tempdir/;
use constant {
    FIXTURE_BASE_DIR => 't/fixtures/',
    FIXTURED_DATA => 'all.yaml'
};

use Data::Dumper;

our $daemon;

sub new {
    my $class = shift;
    $daemon = $class->make_mysqld;
    my $dbh = DBI->connect($daemon->dsn);
    $dbh->do(q{GRANT SELECT ON *.* TO readonly@localhost
                IDENTIFIED BY '' WITH GRANT OPTION});
    $class->create_tables($dbh);
    my $fixture = DBIx::FixtureLoader->new(dbh => $dbh);
    my @data_files = ($ENV{FIXTURED_DATAS}) ? split ' ', $ENV{FIXTURED_DATAS} : (FIXTURED_DATA);
    $fixture->load_fixture(FIXTURE_BASE_DIR . $_ . '.yaml') foreach (@data_files);
    my $dbix_skinny = $class->SUPER::new;
    $dbix_skinny->set_dbh($dbh);
    return $dbix_skinny;
}

sub make_mysqld {
    my $base_dir = tempdir;
    return Test::mysqld->new(
        my_cnf => {
            'skip-networking'    => '',
            innodb_fast_shutdown => 2,
            max_connections      => 1000,
        },
        base_dir => $base_dir,
    ) or die $Test::mysqld::errstr;
}

sub create_tables {
    my ($self, $dbh) = @_;
    open my $fh, '<', 'sql/schema.sql';
    my $sql = do { local $/; <$fh> };
    $dbh->do($sql);
}

sub exists {
    my ($self, $table, $column, $cond) = @_;
    return ($self->count($table, $column, $cond)) ? 1 : 0;
}

1;

@@ DB/Engine/ParseCom
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom;
use strict;
use warnings;
use LWP::UserAgent;
use JSON::XS qw/encode_json/;
use __APP__::Core::Config;
use __APP__::Core::Logger;
use __APP__::Core::DB::Engine::ParseCom::RequestBuilder;
use __APP__::Core::DB::Engine::ParseCom::ResponseBuilder;
use __APP__::Core::Util qw/make_file/;
use constant DEFAULT_LIMIT => 1000;
use Data::Dumper;

sub new {
    my ($class) = @_;
    return bless({
        recall_count => 0,
        logger       => __APP__::Core::Logger->new
    }, $class);
}

sub single {
    my ($self, $table, $params, $option) = @_;
    my $response = $self->call('GET', $table, $params, $option);
    return $response if (ref($response) =~ /Error/);
    return $response unless (ref($response) eq 'ARRAY');
    return $response->[0];
}

sub count {
    my ($self, $table, $params, $option) = @_;
    return $self->call('GET', $table, $params, $option);
}

sub search {
    my ($self, $table, $params, $option) = @_;
    my $skip  = $option->{skip}  || 0;
    my $limit = $option->{limit} || DEFAULT_LIMIT;
    my $is_unlimited_mode = 0;
    if ($limit eq 'unlimited') {
        $is_unlimited_mode = 1;
        $option->{limit} = DEFAULT_LIMIT;
    }
    my @results;
    do {
        $option->{skip} = $skip;
        my $response = $self->call('GET', $table, $params, $option);
        if (ref($response) =~ /Error/) {
            warn Dumper $response;
            return \@results;
        }
        return \@results if (scalar(@$response) == 0);
        push @results, @$response;
        $skip += 1000;
    } while ($is_unlimited_mode || $skip < $limit);
    return \@results;
}

sub insert {
    my ($self, $table, $params) = @_;
    $self->__convert_file_request($params);
    return $self->call('POST', $table, $params);
}

sub update {
    my ($self, $table, $params) = @_;
    return 0 unless $params;
    return 0 unless $params->{object_id};
    $self->__convert_file_request($params);
    return $self->call('PUT', $table, $params);
}

sub upload {
    my ($self, $file) = @_;
    return $self->call('UPLOAD', 'file', $file);
}

sub delete {
    my ($self, $table, $params) = @_;
    return 0 unless defined $params;
    return 0 unless defined $params->{object_id};
    return $self->call('DELETE', $table, $params);
}

sub function {
    my ($self, $function_name, $params) = @_;
    return 0 unless defined $params;
    return $self->call('POST', "functions/$function_name", $params);
}

sub __convert_file_request {
    my ($self, $params) = @_;
    foreach my $key (keys %$params) {
        my $value = $params->{$key};
        if (ref($value) =~ /NohanaDeco::Core::File/) {
            my $response = $self->upload($value);
            unless ($response->{name} && $response->{url}) {
                $self->logger->error('[ERROR] upload error');
                next;
            }
            $params->{$key} = make_file($response->{name});
        }
    }
}

sub call {
    my ($self, $method, $table, $params, $option) = @_;
    my ($original_table, $original_params, $original_option) = ($table, $params, $option);
    my $caller_name = (caller 1)[3];
    my $request = $self->__make_request($method, $table, $params, $option, $caller_name);
    my $ua = LWP::UserAgent->new;
    my $http_response = $ua->request($request);
    my $response = $self->__make_response($method, $caller_name, $http_response);
    if (ref($response) =~ /Error/ && $response->{msg} eq 'parse timeout') {
        my $encoded_params = encode_json $params;
        my $encoded_option = (ref($option) eq 'HASH') ? encode_json $option : '{}';
        $self->{logger}->error_log(<<"ERROR_MESSAGE");

------------------------------------------------------------------------------------------------------------
parse connection fail. retry($self->{recall_count}) connect.
request : caller_name => $caller_name, table => $table, params => $encoded_params, option => $encoded_option
------------------------------------------------------------------------------------------------------------
ERROR_MESSAGE
        no strict 'refs';
        sleep(1);
        return $response if ($self->{recall_count} >= 5);
        $self->{recall_count}++;
        return $self->$caller_name($original_table, $original_params, $original_option);
    }
    $self->{recall_count} = 0;
    return $response;
}

sub __make_request {
    my ($self, $method, $table, $params, $option, $caller_name) = @_;
    my $builder = __APP__::Core::DB::Engine::ParseCom::RequestBuilder->new;
    $builder->caller_name($caller_name);
    $builder->method($method);
    $builder->table($table);
    $builder->query_params($params);
    $builder->query_options($option);
    return $builder->build;
}

sub __make_response {
    my ($self, $method, $caller_name, $http_response) = @_;
    my $response_builder = __APP__::Core::DB::Engine::ParseCom::ResponseBuilder->new;
    $response_builder->caller_name($caller_name);
    $response_builder->method($method);
    return $response_builder->build($http_response);
}

1;

@@ DB/Engine/Fixture/Schema
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::Fixture::Schema;
use strict;
use warnings;
use DBIx::Skinny::Schema;

install_table __TABLE__ => schema {
    pk qw/object_id/;
    columns qw/
        __SCHEMA__
    /;
};

1;

@@ DB/Engine/ParseCom/Util
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom::Util;
use strict;
use warnings;
use parent qw/Exporter/;
use String::CamelCase qw/camelize decamelize/;
use URI::Escape qw/uri_escape/;

my $query_options_map = {
    '<'      => '$lt',
    '<='     => '$lte',
    '>'      => '$gt',
    '>='     => '$gte',
    '!='     => '$ne',
    'in'     => '$in',
    'nin'    => '$nin',
    'regex'  => '$regex',
    'exists' => '$exists',
    'select' => '$select',
    'all'    => '$all',
    'related_to'  => '$relatedTo',
    'dont_select' => '$dontSelect',
};

our @EXPORT_OK = qw/
    format_params
    replace_key_to_snakecase
    replace_key_to_camelcase
    query_options_map
/;

sub query_options_map {
    return $query_options_map;
}

sub replace_key_to_snakecase {
    my ($hashref) = @_;

    foreach my $key (keys %$hashref) {
        next if ($key =~ /^\$/);
        my $snake_case = decamelize $key;
        my $value = $hashref->{$key};
        delete $hashref->{$key};
        $hashref->{$snake_case} = $value;
    }
}

sub replace_key_to_camelcase {
    my ($hashref) = @_;

    foreach my $key (keys %$hashref) {
        next if ($key =~ /^\$/);
        my $camel_case = camelize $key;
        $camel_case =~ s/\.([A-Z])/".".lc($1)/e;
        uri_escape($camel_case);
        $camel_case = lcfirst($camel_case) if ($key =~ /^[a-z]/);
        my $value = $hashref->{$key};
        delete $hashref->{$key};
        $hashref->{$camel_case} = $value;
    }
}

sub format_params {
    my ($params) = @_;

    my %formatted_params;
    foreach my $key (keys %$params) {
        my $value = $params->{$key};
        if (ref $value eq 'ARRAY') {
            $formatted_params{$key} = format_requested_array_object($value);
        } elsif (ref $value eq 'HASH') {
            if ($value->{__type} && $value->{__type} eq 'Pointer') {
                $formatted_params{$key} = $value;
            } else {
                my $hashref = format_requested_hash_object($value);
                $formatted_params{$key} = $hashref;
            }
        } elsif (ref($value) =~ /Relation/) {
            my $hashref = format_relation_object($key, $value);
            $formatted_params{$_} = $hashref->{$_} foreach keys %$hashref;
        } else {
            $formatted_params{$key} = $value;
        }
    }
    return \%formatted_params;
}

sub format_requested_array_object {
    my ($array_ref) = @_;
    my @objects = map { values %$_; } @$array_ref;
    return +{ '$in' => \@objects };
}

sub format_requested_hash_object {
    my ($hash_ref) = @_;

    my %formatted_params;
    foreach my $opt (keys %$hash_ref) {
        my $parse_com_opt = $query_options_map->{$opt} || $opt;
        my $value = $hash_ref->{$opt};
        if (ref($value) =~ /Relation/) {
            $formatted_params{$parse_com_opt} = $value->__raw;
        } else {
            $formatted_params{$parse_com_opt} = $value;
        }
    }
    return \%formatted_params;
}

sub format_relation_object {
    my ($key, $relation) = @_;

    my %formatted_params;
    my $parse_com_opt = $query_options_map->{$key};
    if (defined $parse_com_opt) {
        $formatted_params{$parse_com_opt} = $relation->__raw;
    } else {
        $formatted_params{$key} = $relation->__raw;
    }
    return \%formatted_params;
}

1;

@@ DB/Engine/ParseCom/RequestBuilder
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom::RequestBuilder;
use strict;
use warnings;
use parent qw/Class::Accessor::Fast/;
use HTTP::Request;
use HTTP::Request::Common;
use __APP__::Core::DB::Engine::ParseCom::RequestBuilder::Header;
use __APP__::Core::DB::Engine::ParseCom::RequestBuilder::URL;
use __APP__::Core::DB::Engine::ParseCom::RequestBuilder::Body;

__PACKAGE__->mk_accessors(qw/
    caller_name
    method
    table
    query_params
    query_options
/);

sub new {
    my ($class) = @_;
    return $class->SUPER::new({});
}

sub build {
    my ($self) = @_;
    my $method = $self->method;
    $method = 'POST' if ($method eq 'UPLOAD');
    return HTTP::Request->new(
        $method,
        $self->build_url,
        $self->build_header,
        $self->build_body
    );
}

sub build_url {
    my ($self) = @_;
    my $url_builder = __APP__::Core::DB::Engine::ParseCom::RequestBuilder::URL->new;
    $url_builder->caller_name($self->caller_name);
    $url_builder->method($self->method);
    $url_builder->table($self->table);
    $url_builder->query_params($self->query_params);
    $url_builder->query_options($self->query_options);
    return $url_builder->build;
}

sub build_header {
    my ($self) = @_;
    return __APP__::Core::DB::Engine::ParseCom::RequestBuilder::Header->new->build($self->method, $self->query_params);
}

sub build_body {
    my ($self) = @_;
    my $body_builder = __APP__::Core::DB::Engine::ParseCom::RequestBuilder::Body->new;
    $body_builder->method($self->method);
    $body_builder->query_params($self->query_params);
    return $body_builder->build;
}

1;

@@ DB/Engine/ParseCom/ResponseBuilder
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom::ResponseBuilder;
use strict;
use warnings;
use parent qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/
    caller_name
    method
/);
use JSON::XS;
use __APP__::Core::DB::Engine::ParseCom::Util qw/
    replace_key_to_snakecase
/;
use __APP__::Core::DB::Engine::ParseCom::ResponseBuilder::Error;

sub new {
    my ($class) = @_;
    return $class->SUPER::new;
}

sub build {
    my ($self, $http_response) = @_;
    my $content_or_error = $self->__get_content($http_response);
    return $content_or_error if (ref($content_or_error) =~ /Error/);
    my $body = ($self->caller_name =~ /count/) ? $content_or_error->{count} :
        ($self->caller_name =~ /update/) ? $content_or_error : $content_or_error->{results};
    return undef unless ($body);
    if (ref($body) eq 'ARRAY') {
        replace_key_to_snakecase($_) foreach @$body;
    } elsif (ref($body) eq 'HASH') {
        replace_key_to_snakecase($body);
    }
    return $body;
}

sub __get_content {
    my ($self, $http_response) = @_;
    my $code = $http_response->code;
    return $self->__error('timeout',   $code) if ($self->__is_timeout($http_response));
    return $self->__error('not found', $code) if ($self->__is_not_found($http_response));
    return $self->__error('unauthorized', $code) if ($self->__is_unauthorized($http_response));
    return $self->__error('invalid content', $code) if ($http_response->content eq '');
    if ($self->__has_error($http_response)) {
        if ($http_response->content =~ 'Can\'t connect to api.parse.com:443') {
            return $self->__error('parse timeout', $code);
        } else {
            return $self->__error('error', $code);
        }
    }
    my $decoded_content = eval { decode_json($http_response->content); };
    if (my $e = $@) {
        warn 'malformed JSON string';
        return $self->error('parse timeout', $code);
    }
    return $decoded_content;
}

sub __error {
    my ($self, $msg, $code) = @_;
    return __APP__::Core::DB::Engine::ParseCom::ResponseBuilder::Error->new($msg, $code);
}

sub __has_error {
    my ($self, $response) = @_;
    ($response->code != 200 && $response->code != 201) ? 1 : 0;
}

sub __is_unauthorized {
    my ($self, $response) = @_;
    ($response->code == 401) ? 1 : 0;
}

sub __is_not_found {
    my ($self, $response) = @_;
    ($response->code == 404) ? 1 : 0;
}

sub __is_timeout {
    my ($self, $response) = @_;
    (($response->code == 500) && ($response->content =~ /\(connect: timeout\)/)) ? 1 : 0;
}

1;

@@ DB/Engine/ParseCom/RequestBuilder/Header
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom::RequestBuilder::Header;
use strict;
use warnings;
use __APP__::Core::Config;
use HTTP::Headers;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub build {
    my ($self, $method, $params) = @_;
    my $app_id         = $__APP__::Core::Config::APPLICATION_ID;
    my $master_key     = $__APP__::Core::Config::MASTER_KEY;
    my $restapi_key    = $__APP__::Core::Config::REST_API_KEY;
    my $session_tk     = $__APP__::Core::Config::SESSION_TOKEN;
    my $use_master_key = $__APP__::Core::Config::USE_MASTER_KEY;
    my @master_key_pair  = ('X-Parse-Master-Key'     => $master_key);
    my @restapi_key_pair = ('X-Parse-REST-API-Key'   => $restapi_key);
    my @app_id_pair      = ('X-Parse-Application-Id' => $app_id);
    my @session_tk_pair  = ('X-Parse-Session-Token'  => $session_tk);
    my @content_type     = $self->content_type($method, $params);

    my @header_paramas = ($use_master_key) ? @master_key_pair : @restapi_key_pair;
    push @header_paramas, (@app_id_pair, @session_tk_pair, @content_type);

    return HTTP::Headers->new(@header_paramas);
}

sub content_type {
    my ($self, $method, $params) = @_;
    my @content_json = ('Content_Type' => 'application/json');
    my @content_type = ($method eq 'POST' || $method eq 'PUT') ? @content_json : ();
    if ($method eq 'UPLOAD') {
        my $file = $params;
        @content_type = ('Content_Type' => $file->content_type);
    }
    return @content_type;
}

1;

@@ DB/Engine/ParseCom/RequestBuilder/URL
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom::RequestBuilder::URL;
use strict;
use warnings;
use parent qw/Class::Accessor::Fast/;
use JSON::XS;
use String::CamelCase qw/camelize decamelize/;
use URI::Escape qw/uri_escape/;
use __APP__::Core::DB::Engine::ParseCom::Util qw/
    replace_key_to_camelcase
    format_params
/;

__PACKAGE__->mk_accessors(qw/
    caller_name
    method
    table
    query_params
    query_options
/);

use constant {
    BASE_URL                => 'https://api.parse.com/1/',
    DEFAULT_LIMIT           => 1000,
    USER_TABLE_NAME         => 'user',
    ROLE_TABLE_NAME         => 'role',
    FILE_TABLE_NAME         => 'file',
    INSTALLATION_TABLE_NAME => 'installation'
};

sub new {
    my ($class) = @_;
    return $class->SUPER::new({});
}

sub build {
    my ($self) = @_;
    my $name = $self->caller_name;
    if ($name =~ /single/ || $name =~ /search/ || $name =~ /count/) {
        return $self->build_for_get;
    } elsif ($name =~ /update/ || $name =~ /insert/ || $name =~ /upload/ ||
             $name =~ /delete/ || $name =~ /function/) {
        return $self->build_for_other;
    } else {
        die "sorry, still not supported method : $name";
    }
}

sub build_for_get {
    my ($self) = @_;
    my $query        = $self->build_query_params;
    my $query_string = $self->build_query_string($query);
    my $table_name   = $self->build_request_table_name;
    return BASE_URL . sprintf("%s?%s", $table_name, $query_string);
}

sub build_for_other {
    my ($self) = @_;
    my $table_name = $self->build_request_table_name;
    my $url = BASE_URL . $table_name;
    my $name = $self->caller_name;
    if ($name =~ /update/ || $name =~ /delete/) {
        my $object_id = $self->query_params->{object_id};
        $url .= "/$object_id";
    } elsif ($name =~ /upload/) {
        my $file     = $self->query_params;
        my $filename = $file->filename || 'file' . $file->type;
        $url .= "/$filename";
    }
    return $url;
}

sub build_query_params {
    my ($self) = @_;
    my $formatted_params = format_params($self->query_params);
    my $option = $self->build_query_option($self->query_options);
    if ($self->caller_name =~ /count/) {
        $option->{count} = 1;
        $option->{limit} = 0;
    }
    my $where = (keys %$formatted_params) ? { where => $formatted_params } : {};
    return { %$where, %$option };
}

sub build_query_string {
    my ($self, $query_params) = @_;

    my @params;
    if (defined $query_params->{where}) {
        push @params, $self->build_where_statement($query_params->{where});
        delete $query_params->{where};
    }
    foreach my $key (keys %$query_params) {
        my $value = $query_params->{$key};
        push @params, sprintf("%s=%s", $key, (ref $value eq 'HASH') ? encode_json($value) : $value);
    }
    $self->{params} = \@params;
    return join('&', map {
        $_;
        #uri_escape($_)
    } @params);
}

sub build_query_option {
    my ($self, $option) = @_;
    my $limit = $option->{limit} || DEFAULT_LIMIT;
    my $parsed_option = { limit => $limit };
    return $parsed_option unless $option;
    if (defined $option->{order_by}) {
        my $orders = $option->{order_by};
        my @order_properties;
        foreach my $order_name (keys %$orders) {
            my $order = $orders->{$order_name};
            push @order_properties, ($order eq 'desc') ? "-$order_name" : $order_name;
        }
        $parsed_option->{order} = join(',', @order_properties);
        delete $option->{order_by};
    }
    $parsed_option->{$_} = $option->{$_} foreach keys %$option;
    return $parsed_option;
}

sub build_request_table_name {
    my ($self) = @_;
    my $table = $self->table;
    my $is_standard_table = $self->__is_parse_standard_table($table);
    return ($is_standard_table) ? $table . 's' : sprintf("classes/%s", camelize($table));
}

sub __is_parse_standard_table {
    my ($self, $table) = @_;
    return 1 if ($table eq USER_TABLE_NAME);
    return 1 if ($table eq ROLE_TABLE_NAME);
    return 1 if ($table eq FILE_TABLE_NAME);
    return 1 if ($table eq INSTALLATION_TABLE_NAME);
    return 0;
}

sub build_where_statement {
    my ($self, $where) = @_;
    my $where_statement;
    if (ref $where eq 'HASH') {
        replace_key_to_camelcase($where);
        $where_statement = sprintf("where=%s", encode_json($where));
    } else {
        $where_statement = sprintf("where=%s", $where);
    }
    return $where_statement;
}

1;

@@ DB/Engine/ParseCom/RequestBuilder/Body
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom::RequestBuilder::Body;
use strict;
use warnings;
use parent qw/Class::Accessor::Fast/;
use JSON::XS;
use __APP__::Core::DB::Engine::ParseCom::Util qw/
    replace_key_to_camelcase
    format_params
/;

__PACKAGE__->mk_accessors(qw/
    method
    query_params
/);

sub new {
    my ($class) = @_;
    return $class->SUPER::new({});
}

sub build {
    my ($self) = @_;
    if ($self->method eq 'UPLOAD') {
        my $file = $self->query_params;
        return $file->binary_data;
    }
    my $formatted_params = format_params($self->query_params);
    replace_key_to_camelcase($formatted_params);
    return encode_json($formatted_params);
}

1;

@@ DB/Engine/ParseCom/ResponseBuilder/Error
# This code was automatically generated by App::Harmonia (version __VERSION__)
package __APP__::Core::DB::Engine::ParseCom::ResponseBuilder::Error;
use strict;
use warnings;
use parent qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/
    msg
    code
/);

sub new {
    my ($class, $msg, $status_code) = @_;
    my $self = {
        msg  => $msg,
        code => $status_code
    };
    return $class->SUPER::new($self);
}

1;
