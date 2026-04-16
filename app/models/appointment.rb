# frozen_string_literal: true

class Appointment < ApplicationRecord
  STATUSES = %w[scheduled confirmed arrived in_progress completed cancelled no_show].freeze
  FINAL_STATUSES = %w[completed cancelled no_show].freeze

  belongs_to :organization
  belongs_to :patient
  belongs_to :practitioner

  validates :start_time, :end_time, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate  :end_time_after_start_time
  validate  :not_editable_if_finalized, on: :update

  scope :upcoming, -> { where("start_time > ?", Time.current).order(:start_time) }
  scope :for_date, ->(date) { where(start_time: date.all_day) }
  scope :for_practitioner, ->(practitioner) { where(practitioner: practitioner) }

  def duration_minutes
    ((end_time - start_time) / 60).to_i
  end

  def finalized?
    FINAL_STATUSES.include?(status)
  end

  def cancel!(reason:)
    raise ActiveRecord::ReadOnlyRecord, "Appointment is already finalized" if finalized?

    update!(status: "cancelled", cancel_reason: reason, cancelled_at: Time.current)
  end

  def as_api_json
    {
      id: id,
      organization_id: organization_id,
      patient_id: patient_id,
      practitioner_id: practitioner_id,
      room_id: room_id,
      start_time: start_time,
      end_time: end_time,
      duration_minutes: duration_minutes,
      appointment_type: appointment_type,
      status: status,
      reason: reason,
      notes: notes,
      is_online: is_online,
      is_teleconsultation: is_teleconsultation,
      teleconsultation_link: teleconsultation_link,
      cancel_reason: cancel_reason,
      cancelled_at: cancelled_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end

  def not_editable_if_finalized
    return unless finalized? && status_was != status

    errors.add(:base, "Cannot modify a finalized appointment. Use cancel! for cancellation.")
  end
end
