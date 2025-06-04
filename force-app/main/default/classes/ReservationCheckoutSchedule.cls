public class ReservationCheckoutSchedule implements Schedulable {
    public void execute(SchedulableContext sc) {
        CheckoutStatusBatchClass batch = new CheckoutStatusBatchClass();
        Database.executeBatch(batch);
    }
}