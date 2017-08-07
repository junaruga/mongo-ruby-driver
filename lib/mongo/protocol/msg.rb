# Copyright (C) 2014-2016 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongo
  module Protocol

    # MongoDB Wire protocol Msg message (OP_MSG), a bi-directional wire protocol opcode.
    #
    # OP_MSG is only available in MongoDB 3.6 (maxWireVersion >= 6) and later.
    #
    # @api private
    #
    # @since 2.5.0
    class Msg < Message

      # Creates a new OP_MSG protocol message
      #
      # @example
      #
      # @api private
      #
      # @since 2.5.0
      def initialize(flag_bits, options, command, *sections)
        @flag_bits = flag_bits || [ :none ]
        @options = options
        @sections = [ command ] + sections
        @global_args = command[:document]
        @request_id = nil
        super
      end

      # Command messages require replies from the database.
      #
      # @example Does the message require a reply?
      #   message.replyable?
      #
      # @return [ true ] Always true for OP_MSG.
      #
      # @since 2.5.0
      def replyable?
        @replyable ||= !@flag_bits.include?(:more_to_come)
      end

      # Return the event payload for monitoring.
      #
      # @example Return the event payload.
      #   message.payload
      #
      # @return [ BSON::Document ] The event payload.
      #
      # @since 2.5.0
      def payload
        BSON::Document.new(
          command_name: global_args.keys.first,
          database_name: global_args[DATABASE_IDENTIFIER],
          command: global_args,
          request_id: request_id,
          reply: global_args
        )
      end

      private

      DATABASE_IDENTIFIER = '$db'.freeze

      def global_args
        @global_args ||= sections[0]
      end

      # The operation code required to specify a OP_MSG message.
      # @return [ Fixnum ] the operation code.
      #
      # @since 2.5.0
      OP_CODE = 2013

      # Available flags for a OP_MSG message.
      FLAGS = Array.new(16).tap { |arr|
        arr[0] = :checksum_present
        arr[1] = :more_to_come
      }

      # @!attribute
      # @return [Array<Symbol>] The flags for this message.
      field :flag_bits, BitVector.new(FLAGS)

      # @!attribute
      # @return [Hash] The sections of payload type 1 or 0.
      field :sections, Sections
      alias :documents :sections

      #field :checksum, Checksum

      Registry.register(OP_CODE, self)
    end
  end
end
