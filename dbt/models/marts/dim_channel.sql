select channel_id, channel_name, channel_group, is_active from {{ ref('stg_channels') }}
