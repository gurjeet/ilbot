--supposed to be run as a superuser.
-- make sure the database is UTF-8 encoded

begin transaction;

drop schema if exists ilbot cascade;

drop user if exists ilbot;

create user ilbot login password 'CHANGE IMMEDIATELY; SET SECRET PASSWORD';

create schema ilbot authorization ilbot;

set search_path = ilbot;

set role ilbot;

drop table if exists irclog;

/* Some limits picked up from http://www.ietf.org/rfc/rfc1459.txt
   Although we know the limits imposed by the protocol on some string lengths,
   we are here to log everything and not to correct someone else's
   implementation of the protocol. So we'll be very accomodating in the strings
   we digest. Since a TEXT has the same overhead as a VARCHAR, but does not
   require a precision, we'll be using TEXT so that we don't fail on unreasonably
   long strings. But we'll have some mechanish to keep an eye on strings
   that exceed what the protocol allows, and report it to the server operators at
   our convenience.
*/

create table server( id serial primary key, name text, url text );
create table channel( server_id integer, id serial, name text /*limit 200*/, primary key( server_id, id ), foreign key( server_id ) references server );
create table nick( server_id integer, id serial, name text /*limit 9*/, primary key( server_id, id ), foreign key( server_id ) references server );

create type irc_actions as enum( 'said', 'emoted', 'joined', 'part', 'quit', 'change_nick', 'topic', 'kicked' );

create table irclog(
	server integer,
	channel integer,
	nick integer,
	action irc_actions,
	logged_at timestamp with time zone default now(),
	line text,
	spam bool default false,
	foreign key( server, nick ) references nick,
	foreign key( server, channel ) references channel
);

create or replace function log_action( p_server text, p_channel text, p_nick text, p_action irc_actions, p_line text ) returns void as $$
declare
	l_server_id integer;
	l_channel_id integer;
	l_nick_id integer;
begin
	l_server_id := (select id from server where name = p_server);
	if( l_server_id is null ) then
		insert into server( name ) values ( p_server );
		l_server_id := (select id from server where name = p_server);
	end if;

	l_channel_id := (select id from channel where server_id = l_server_id and name = p_channel );
	if( l_channel_id is null ) then
		insert into channel( server_id, name ) values( l_server_id, p_channel );
		l_channel_id := (select id from channel where server_id = l_server_id and name = p_channel );
	end if;

	l_nick_id := (select id from nick where server_id = l_server_id and name = p_nick );
	if( l_nick_id is null ) then
		insert into nick( server_id, name ) values( l_server_id, p_nick );
		l_nick_id := (select id from nick where server_id = l_server_id and name = p_nick );
	end if;

	insert into irclog( server, channel, nick, action, line ) values( l_server_id, l_channel_id, l_nick_id, p_action, p_line );
	
end;
$$ language plpgsql;

commit transaction;

-- vim: sw=4 ts=4
